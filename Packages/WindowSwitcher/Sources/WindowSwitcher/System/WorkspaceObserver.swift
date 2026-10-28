import AppKit

/// NSWorkspace and screen notifications (PLAN §6.5): launch, terminate, activate, hide, unhide, active Space
/// change and screen parameters, plus the moments a locked or inactive session comes back. Each one becomes
/// a `WindowSourceEvent`; nothing polls.
final class WorkspaceObserver {
    private var tokens: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    private static let applicationNotifications: [Notification.Name] = [
        NSWorkspace.didLaunchApplicationNotification,
        NSWorkspace.didTerminateApplicationNotification,
        NSWorkspace.didActivateApplicationNotification,
        NSWorkspace.didHideApplicationNotification,
        NSWorkspace.didUnhideApplicationNotification,
    ]

    /// Posted by the system when the lock screen goes away (undocumented, long-standing).
    static let screenUnlocked = Notification.Name("com.apple.screenIsUnlocked")

    func start(sink: @escaping @Sendable (WindowSourceEvent) -> Void) {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in Self.applicationNotifications {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let event = Self.event(for: note.name, pid: app.processIdentifier)
                else { return }
                sink(event)
            }
            tokens.append((workspace, token))
        }
        observe(NSWorkspace.activeSpaceDidChangeNotification, on: workspace) { sink(.activeSpaceChanged) }
        observe(NSApplication.didChangeScreenParametersNotification, on: .default) { sink(.screensChanged) }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(name, on: workspace) { sink(.sessionResumed) }
        }
        observe(Self.screenUnlocked, on: DistributedNotificationCenter.default()) { sink(.sessionResumed) }
    }

    func stop() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    nonisolated static func event(for name: Notification.Name, pid: Int32) -> WindowSourceEvent? {
        switch name {
        case NSWorkspace.didLaunchApplicationNotification: .appLaunched(pid)
        case NSWorkspace.didTerminateApplicationNotification: .appTerminated(pid)
        case NSWorkspace.didActivateApplicationNotification: .appActivated(pid)
        case NSWorkspace.didHideApplicationNotification: .appHidden(pid)
        case NSWorkspace.didUnhideApplicationNotification: .appUnhidden(pid)
        default: nil
        }
    }

    private func observe(_ name: Notification.Name, on center: NotificationCenter, _ handler: @escaping @Sendable () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in handler() }
        tokens.append((center, token))
    }
}
