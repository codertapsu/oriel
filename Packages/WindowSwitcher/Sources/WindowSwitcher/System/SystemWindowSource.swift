import AppKit
import PrivateAPIs

/// The real `WindowSource`: Accessibility through the AX actor, `CGWindowListCopyWindowInfo`, and SkyLight
/// Spaces through `PrivateAPIs` (PLAN §7.1.1).
///
/// With `observesChanges` it installs AX observers per app and the workspace observers and reports changes on
/// `events`. Without, it only answers reads; the CLI and the read-only TCC test use it that way.
final nonisolated class SystemWindowSource: WindowSource {
    let events: AsyncStream<WindowSourceEvent>
    let capabilities: SourceCapabilities

    private let continuation: AsyncStream<WindowSourceEvent>.Continuation
    private let ax: AXClient
    private let apis: PrivateAPIs
    private let workspace: WorkspaceObserver?

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
    }

    func start() async {
        guard let workspace else { return }
        let continuation = continuation
        await workspace.start { continuation.yield($0) }
    }

    func stop() async {
        await workspace?.stop()
        await ax.removeAllObservers()
        continuation.finish()
    }

    func applications() async -> [AppRecord] {
        await MainActor.run { Self.runningApplications() }
    }

    func accessibilityWindows(of pid: Int32) async -> AXWindowsResult {
        await ax.windows(of: pid)
    }

    func otherSpaceWindows(of pid: Int32, ids: Set<UInt32>) async -> [AXWindowRecord] {
        await ax.otherSpaceWindows(of: pid, ids: ids)
    }

    func focusedWindowID(of pid: Int32) async -> UInt32? {
        await ax.focusedWindowID(of: pid)
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
        await WindowFocuser(ax: ax, apis: apis).focus(window)
    }

    func perform(_ action: WindowAction, on window: WindowEntry) async -> Bool {
        guard window.isActionable else { return false }
        return switch action {
        case .close: await ax.close(windowID: window.id)
        case .minimize: await ax.setMinimized(true, windowID: window.id)
        case .toggleFullScreen: await ax.toggleFullScreen(windowID: window.id)
        }
    }

    func setMinimized(_ minimized: Bool, window: WindowEntry) async -> Bool {
        guard window.isActionable else { return false }
        return await ax.setMinimized(minimized, windowID: window.id)
    }

    func quit(pid: Int32) async -> Bool {
        await MainActor.run { NSRunningApplication(processIdentifier: pid)?.terminate() ?? false }
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
