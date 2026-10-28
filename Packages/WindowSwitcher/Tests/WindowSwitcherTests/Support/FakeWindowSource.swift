import CoreGraphics
import OrielCore
@testable import WindowSwitcher

/// A scripted `WindowSource`: tests set the system's state, send events and read back what the store asked.
actor FakeWindowSource: WindowSource {
    nonisolated let events: AsyncStream<WindowSourceEvent>
    nonisolated let capabilities: SourceCapabilities
    private let continuation: AsyncStream<WindowSourceEvent>.Continuation

    private(set) var apps: [AppRecord] = []
    private(set) var accessibility: [Int32: AXWindowsResult] = [:]
    /// What cached elements and remote tokens reach for windows AX does not list.
    private(set) var reachable: [UInt32: AXWindowRecord] = [:]
    private(set) var server: [ServerWindowRecord] = []
    private(set) var displayList: [DisplayInfo] = []
    private(set) var spaceSnapshot: SpaceSnapshot?
    private(set) var focused: [Int32: UInt32] = [:]

    private(set) var accessibilityReads: [Int32] = []
    private(set) var otherSpaceRequests: [Int32: Set<UInt32>] = [:]
    private(set) var focusRequests: [UInt32] = []
    private(set) var performed: [String] = []
    private(set) var quitRequests: [Int32] = []
    private(set) var forgotten: [Int32] = []
    private(set) var isStarted = false

    init(capabilities: SourceCapabilities = SourceCapabilities()) {
        let (stream, continuation) = AsyncStream.makeStream(of: WindowSourceEvent.self)
        events = stream
        self.continuation = continuation
        self.capabilities = capabilities
    }

    // MARK: Scripting

    func set(apps: [AppRecord]) {
        self.apps = apps
    }

    func set(accessibility result: AXWindowsResult, for pid: Int32) {
        accessibility[pid] = result
    }

    func set(reachable records: [AXWindowRecord]) {
        reachable = Dictionary(
            records.compactMap { record in record.windowID.map { ($0, record) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func set(server: [ServerWindowRecord]) {
        self.server = server
    }

    func set(spaces: SpaceSnapshot?) {
        spaceSnapshot = spaces
    }

    func set(displays: [DisplayInfo]) {
        displayList = displays
    }

    func set(focused windowID: UInt32, for pid: Int32) {
        focused[pid] = windowID
    }

    func resetCounters() {
        accessibilityReads = []
        otherSpaceRequests = [:]
    }

    nonisolated func send(_ event: WindowSourceEvent) {
        continuation.yield(event)
    }

    // MARK: WindowSource

    func start() {
        isStarted = true
    }

    func stop() {
        continuation.finish()
    }

    func applications() -> [AppRecord] {
        apps
    }

    func accessibilityWindows(of pid: Int32) -> AXWindowsResult {
        accessibilityReads.append(pid)
        return accessibility[pid] ?? .windows([])
    }

    func otherSpaceWindows(of pid: Int32, ids: Set<UInt32>) -> [AXWindowRecord] {
        otherSpaceRequests[pid, default: []].formUnion(ids)
        guard capabilities.canReachOtherSpaces else { return [] }
        return ids.sorted().compactMap { id in
            guard var record = reachable[id] else { return nil }
            record.isListed = false
            return record
        }
    }

    func focusedWindowID(of pid: Int32) -> UInt32? {
        focused[pid]
    }

    func serverWindows() -> [ServerWindowRecord] {
        server
    }

    func displays() -> [DisplayInfo] {
        displayList
    }

    func spaces(for windowIDs: [UInt32]) -> SpaceSnapshot? {
        guard var snapshot = spaceSnapshot else { return nil }
        let wanted = Set(windowIDs)
        snapshot.windowSpaces = snapshot.windowSpaces.filter { wanted.contains($0.key) }
        return snapshot
    }

    func forget(pid: Int32) {
        forgotten.append(pid)
    }

    func prune(keeping _: Set<UInt32>) {}

    func focus(_ window: WindowEntry) -> Bool {
        focusRequests.append(window.id)
        return true
    }

    func perform(_ action: WindowAction, on window: WindowEntry) -> Bool {
        performed.append("\(action.rawValue) \(window.id)")
        return window.isActionable
    }

    func setMinimized(_ minimized: Bool, window: WindowEntry) -> Bool {
        performed.append("\(minimized ? "minimize" : "restore") \(window.id)")
        return window.isActionable
    }

    func quit(pid: Int32) -> Bool {
        quitRequests.append(pid)
        return true
    }
}
