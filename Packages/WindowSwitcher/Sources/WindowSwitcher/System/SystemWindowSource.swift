import AppKit
import PrivateAPIs

/// The real `WindowSource`: Accessibility through the AX actor, `CGWindowListCopyWindowInfo`, and SkyLight
/// Spaces through `PrivateAPIs` (PLAN §7.1.1). Oriel's own windows come from AppKit (`OwnWindows`): an AX request to its
/// own process would run AppKit off the main thread (`AXClient.ownPID`).
///
/// With `observesChanges` it installs AX observers per app, the workspace observers and an observer of Oriel's own
/// windows, and reports changes on `events`. Without, it only answers reads; the CLI and the read-only TCC test use it
/// that way.
final nonisolated class SystemWindowSource: WindowSource {
    let events: AsyncStream<WindowSourceEvent>
    let capabilities: SourceCapabilities

    private let continuation: AsyncStream<WindowSourceEvent>.Continuation
    private let ax: AXClient
    private let apis: PrivateAPIs
    private let workspace: WorkspaceObserver?
    private let ownWindows: OwnWindowObserver?
    private let ownPID = AXClient.ownPID

    @MainActor
    init(observesChanges: Bool, apis: PrivateAPIs = .shared) {
        let (stream, continuation) = AsyncStream.makeStream(of: WindowSourceEvent.self)
        events = stream
        self.continuation = continuation
        self.apis = apis
        capabilities = SourceCapabilities(apis: apis)
        let relay = observesChanges ? AXNotificationRelay { continuation.yield($0) } : nil
        ax = AXClient(apis: apis, relay: relay)
        workspace = observesChanges ? WorkspaceObserver() : nil
        ownWindows = observesChanges ? OwnWindowObserver() : nil
    }

    func start() async {
        guard let workspace else { return }
        let continuation = continuation
        await workspace.start { continuation.yield($0) }
        await ownWindows?.start(pid: ownPID) { continuation.yield($0) }
    }

    func stop() async {
        await workspace?.stop()
        await ownWindows?.stop()
        await ax.removeAllObservers()
        continuation.finish()
    }

    func applications() async -> [AppRecord] {
        await MainActor.run { Self.runningApplications() }
    }

    func accessibilityWindows(of pid: Int32) async -> AXWindowsResult {
        if pid == ownPID {
            return await .windows(MainActor.run { OwnWindows.records() })
        }
        return await ax.windows(of: pid)
    }

    /// None for Oriel: AppKit lists its windows on every Space.
    func otherSpaceWindows(of pid: Int32, ids: Set<UInt32>) async -> [AXWindowRecord] {
        guard pid != ownPID else { return [] }
        return await ax.otherSpaceWindows(of: pid, ids: ids)
    }

    func focusedWindowID(of pid: Int32) async -> UInt32? {
        if pid == ownPID {
            return await MainActor.run { OwnWindows.focusedWindowID }
        }
        return await ax.focusedWindowID(of: pid)
    }

    func serverWindows() async -> [ServerWindowRecord] {
        ServerWindowList.current()
    }

    func displays() async -> [DisplayInfo] {
        DisplayDirectory.current()
    }

    func spaces(for windowIDs: [UInt32]) async -> SpaceSnapshot? {
        SpaceReader.snapshot(for: windowIDs, displays: DisplayDirectory.current(), apis: apis)
    }

    func forget(pid: Int32) async {
        await ax.forget(pid: pid)
    }

    func prune(keeping windowIDs: Set<UInt32>) async {
        await ax.prune(keeping: windowIDs)
    }

    func focus(_ window: WindowEntry) async -> Bool {
        if window.info.pid == ownPID {
            let id = window.id
            return await MainActor.run { OwnWindows.focus(id) }
        }
        return await WindowFocuser(ax: ax, apis: apis).focus(window)
    }

    func perform(_ action: WindowAction, on window: WindowEntry) async -> Bool {
        if window.info.pid == ownPID {
            let id = window.id
            return await MainActor.run { OwnWindows.perform(action, on: id) }
        }
        guard window.isActionable else { return false }
        return switch action {
        case .close: await ax.close(windowID: window.id)
        case .minimize: await ax.setMinimized(true, windowID: window.id)
        case .toggleFullScreen: await ax.toggleFullScreen(windowID: window.id)
        }
    }

    func setMinimized(_ minimized: Bool, window: WindowEntry) async -> Bool {
        if window.info.pid == ownPID {
            let id = window.id
            return await MainActor.run { OwnWindows.setMinimized(minimized, id: id) }
        }
        guard window.isActionable else { return false }
        return await ax.setMinimized(minimized, windowID: window.id)
    }

    /// Never Oriel itself: only Quit in its menu quits it.
    func quit(pid: Int32) async -> Bool {
        guard pid != ownPID else { return false }
        return await MainActor.run { NSRunningApplication(processIdentifier: pid)?.terminate() ?? false }
    }

    @MainActor
    private static func runningApplications() -> [AppRecord] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard !app.isTerminated else { return nil }
            let policy: AppRecord.Policy
            switch app.activationPolicy {
            case .regular: policy = .regular
            case .accessory: policy = .accessory
            default: return nil
            }
            let pid = app.processIdentifier
            return AppRecord(
                pid: pid,
                bundleID: app.bundleIdentifier,
                name: app.localizedName ?? app.bundleIdentifier ?? "pid \(pid)",
                policy: policy,
                isHidden: app.isHidden,
                isActive: app.isActive
            )
        }
    }
}
