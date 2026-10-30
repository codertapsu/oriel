import AppKit

/// Tells the store when one of Oriel's own windows appears, goes away, changes or takes focus: the events AX observers
/// report for other apps, which the switcher installs none of on its own process (`AXClient.ownPID`).
final class OwnWindowObserver {
    private var tokens: [any NSObjectProtocol] = []

    /// A window ordered in or out changes its occlusion state, so that one notification covers showing and hiding.
    private static let changes: [Notification.Name] = [
        NSWindow.didChangeOcclusionStateNotification,
        NSWindow.willCloseNotification,
        NSWindow.didMiniaturizeNotification,
        NSWindow.didDeminiaturizeNotification,
        NSWindow.didEnterFullScreenNotification,
        NSWindow.didExitFullScreenNotification,
    ]
    private static let focus: [Notification.Name] = [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification]

    func start(pid: Int32, sink: @escaping @Sendable (WindowSourceEvent) -> Void) {
        guard tokens.isEmpty else { return }
        let center = NotificationCenter.default
        for name in Self.changes + Self.focus {
            let event: WindowSourceEvent = Self.focus.contains(name) ? .focusedWindowChanged(pid) : .windowsChanged(pid)
            let token = center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let window = note.object as? NSWindow, MainActor.assumeIsolated({ OwnWindows.isStandard(window) })
                else { return }
                sink(event)
            }
            tokens.append(token)
        }
    }

    func stop() {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll()
    }
}
