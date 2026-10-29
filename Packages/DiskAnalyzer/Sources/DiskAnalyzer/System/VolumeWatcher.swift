import AppKit

/// Calls `onChange` when a volume is mounted, unmounted or renamed, from `NSWorkspace`'s notifications: the sidebar
/// follows the drives the user plugs in without polling. Only while the window is open.
final class VolumeWatcher {
    var onChange: (() -> Void)?
    private var observers: [any NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onChange?() }
            })
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
    }
}
