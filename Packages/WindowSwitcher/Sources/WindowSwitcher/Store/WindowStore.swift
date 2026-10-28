import Foundation
import OrielCore
import os

/// The source of truth for windows (PLAN §6.4): a service actor that reads a `WindowSource`, merges the three
/// views of the system, keeps the MRU order and publishes immutable snapshots.
///
/// Event-driven only. Events mark work as pending; a single drain task does the work and, while it awaits the
/// source, further events for the same app merge into the next pass instead of queueing their own re-read.
actor WindowStore {
    private let source: any WindowSource
    private var rules: EligibilityRules
    private let log = Log.logger("switcher")

    private var apps: [Int32: AppRecord] = [:]
    private var listedWindows: [Int32: [AXWindowRecord]] = [:]
    private var otherWindows: [Int32: [AXWindowRecord]] = [:]
    private var refused: Set<Int32> = []
    private var server: [ServerWindowRecord] = []
    private var displays: [DisplayInfo] = []
    private var spaces: SpaceSnapshot?
    private var mru = MRUList()

    /// The switcher's windows, most recently used first.
    private(set) var entries: [WindowEntry] = []
    private(set) var isBootstrapped = false

    private var pending = PendingWork()
    private var drainTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<[WindowEntry]>.Continuation] = [:]

    init(source: any WindowSource, rules: EligibilityRules = EligibilityRules()) {
        self.source = source
        self.rules = rules
    }

    // MARK: Lifecycle

    /// Starts the source's observers, reads everything once, then follows events until the task is cancelled.
    func run() async {
        await source.start()
        if !isBootstrapped {
            await bootstrap()
        }
        for await event in source.events {
            note(event)
        }
        drainTask?.cancel()
    }

    /// One full read: apps, the server list and Spaces, every app's AX windows, other-Space windows.
    func bootstrap() async {
        apps = await Self.index(source.applications())
        await refreshServer()
        let relevant = relevantPIDs()
        for pid in relevant {
            await readAccessibility(of: pid)
        }
        await resolveOtherSpaces(for: relevant)
        // Until focus events arrive, the server's front-to-back order is the best guess at recency.
        mru.seed(server.filter(\.isOnScreen).map(\.id))
        if let active = apps.values.first(where: \.isActive), let focused = await source.focusedWindowID(of: active.pid) {
            mru.touch(focused)
        }
        isBootstrapped = true
        rebuild()
        let windowCount = entries.count
        let appCount = apps.count
        log.debug("bootstrap: \(windowCount) windows of \(appCount) apps")
        // Work noted while bootstrapping (a refresh request, say) runs now.
        if !pending.isEmpty {
            kick()
        }
    }

    /// Applies events and waits until the store has caught up. The event loop and tests use it.
    func process(_ events: [WindowSourceEvent]) async {
        for event in events {
            note(event)
        }
        await settle()
    }

    /// Re-reads the server list and Spaces (cheap) and waits for the result: before the CLI answers, and when
    /// the switcher opens, as a safety net for missed notifications.
    func refresh() async {
        pending.server = true
        await settle()
    }

    /// A new value whenever the windows change, starting with the current one.
    func snapshots() -> AsyncStream<[WindowEntry]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [WindowEntry].self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(entries)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id) }
        }
        return stream
    }

    func setRules(_ rules: EligibilityRules) {
        guard rules != self.rules else { return }
        self.rules = rules
        rebuild()
    }

    /// The switcher focused a window itself: move it to the front without waiting for the notification.
    func noteFocused(_ windowID: UInt32) {
        mru.touch(windowID)
        rebuild()
    }

    func entry(for windowID: UInt32) -> WindowEntry? {
        entries.first { $0.id == windowID }
    }

    /// Stops the drain task and the subscribers.
    func shutdown() {
        drainTask?.cancel()
        drainTask = nil
        for continuation in subscribers.values {
            continuation.finish()
        }
        subscribers.removeAll()
    }

    // MARK: Events

    private func note(_ event: WindowSourceEvent) {
        if case let .appTerminated(pid) = event {
            apps[pid] = nil
            listedWindows[pid] = nil
            otherWindows[pid] = nil
            refused.remove(pid)
        }
        pending.add(event, refused: refused)
        kick()
    }

    private func kick() {
        guard drainTask == nil, isBootstrapped else { return }
        drainTask = Task { await self.drain() }
    }

    private func settle() async {
        kick()
        while let task = drainTask {
            await task.value
        }
    }

    private func drain() async {
        while !pending.isEmpty, !Task.isCancelled {
            let work = pending
            pending = PendingWork()
            await perform(work)
        }
        drainTask = nil
    }

    private func perform(_ work: PendingWork) async {
        for pid in work.terminated {
            await source.forget(pid: pid)
        }
        var appsChanged = false
        if work.applications {
            let fresh = await Self.index(source.applications())
            // Activation alone changes `isActive`, which says nothing about windows.
            appsChanged = Set(fresh.keys) != Set(apps.keys) || fresh.values.contains { apps[$0.pid]?.isHidden != $0.isHidden }
            for pid in Set(apps.keys).subtracting(fresh.keys) {
                listedWindows[pid] = nil
                otherWindows[pid] = nil
            }
            apps = fresh
        }
        var spacesChanged = false
        if work.server || work.allApps || !work.pids.isEmpty || appsChanged {
            spacesChanged = await refreshServer()
        }
        let relevant = relevantPIDs()
        let reread = work.allApps ? relevant : work.pids.intersection(relevant)
        for pid in reread.sorted() {
            await readAccessibility(of: pid)
        }
        let resolve = spacesChanged || work.allApps || appsChanged ? relevant : reread
        await resolveOtherSpaces(for: resolve)
        for pid in work.focusPIDs {
            if let focused = await source.focusedWindowID(of: pid) {
                mru.touch(focused)
            }
        }
        rebuild()
    }

    // MARK: Reading

    /// Returns whether the Space layout or membership changed.
    @discardableResult
    private func refreshServer() async -> Bool {
        server = await source.serverWindows()
        displays = await source.displays()
        let ids = server.filter { apps[$0.pid] != nil && rules.accepts($0) }.map(\.id)
        let fresh = await source.spaces(for: ids)
        let changed = fresh != spaces
        spaces = fresh
        await source.prune(keeping: Set(server.map(\.id)))
        return changed
    }

    private func readAccessibility(of pid: Int32) async {
        switch await source.accessibilityWindows(of: pid) {
        case let .windows(records):
            listedWindows[pid] = records
            refused.remove(pid)
        case .refused:
            // Keep what an unresponsive app showed before; a launching app has nothing yet.
            refused.insert(pid)
        }
    }

    private func resolveOtherSpaces(for pids: Set<Int32>) async {
        for pid in pids.sorted() {
            guard let app = apps[pid], !refused.contains(pid) else { continue }
            let listed = Set((listedWindows[pid] ?? []).compactMap(\.windowID))
            let candidates = WindowMerger.otherSpaceCandidates(
                of: app, listed: listed, serverWindows: server, spaces: spaces, rules: rules
            )
            otherWindows[pid] = candidates.isEmpty ? [] : await source.otherSpaceWindows(of: pid, ids: candidates)
        }
    }

    /// Regular apps, and accessory apps that own a layer-0 window big enough to matter (PLAN §7.1.1 item 1)
    /// that is on screen or on some Space. On macOS 27 many agents (loginwindow, Siri, launchers) own only
    /// off-screen 500×500 helpers on no Space, and every app's first AX request costs 10–60 ms.
    private func relevantPIDs() -> Set<Int32> {
        let owners = Set(server.lazy.filter { window in
            self.rules.accepts(window) && (window.isOnScreen || !(self.spaces?.windowSpaces[window.id] ?? []).isEmpty)
        }.map(\.pid))
        return Set(apps.values.filter { $0.policy == .regular || owners.contains($0.pid) }.map(\.pid))
    }

    // MARK: Output

    private func rebuild() {
        guard isBootstrapped else { return }
        var axWindows: [Int32: [AXWindowRecord]] = [:]
        for pid in Set(listedWindows.keys).union(otherWindows.keys) {
            axWindows[pid] = (listedWindows[pid] ?? []) + (otherWindows[pid] ?? [])
        }
        let relevant = relevantPIDs()
        let input = MergeInput(
            apps: apps.values.filter { relevant.contains($0.pid) }.sorted { $0.pid < $1.pid },
            axWindows: axWindows,
            serverWindows: server,
            spaces: spaces,
            displays: displays,
            rules: rules,
            canReachOtherSpaces: source.capabilities.canReachOtherSpaces
        )
        let merged = WindowMerger.merge(input)
        mru.prune(keeping: Set(server.map(\.id)).union(merged.map(\.id)))
        mru.seed(merged.map(\.id))
        let ordered = mru.sorted(merged, by: \.id)
        guard ordered != entries else { return }
        entries = ordered
        for continuation in subscribers.values {
            continuation.yield(ordered)
        }
    }

    private func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }

    private static func index(_ records: [AppRecord]) -> [Int32: AppRecord] {
        Dictionary(records.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
