import AppKit
import ApplicationServices

/// Notices when Accessibility is granted, without polling (PLAN §7.1.1 item 1: bootstrap "whenever
/// Accessibility is granted"). macOS posts `com.apple.accessibility.api` when the trusted-apps list changes;
/// as a fallback, any app coming to the front (the user leaving System Settings) or Oriel becoming active
/// triggers the same check.
final class AccessibilityTrustObserver {
    private var tokens: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    private var pending: Task<Void, Never>?

    var isObserving: Bool {
        !tokens.isEmpty
    }

    func start(onTrusted: @escaping @MainActor () -> Void) {
        guard tokens.isEmpty else { return }
        let distributed = DistributedNotificationCenter.default()
        let changed = distributed
            .addObserver(forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.check(onTrusted) }
            }
        tokens.append((distributed, changed))
        let active = NotificationCenter.default
            .addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.check(onTrusted) }
            }
        tokens.append((NotificationCenter.default, active))
        let workspace = NSWorkspace.shared.notificationCenter
        let frontmost = workspace
            .addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.check(onTrusted) }
            }
        tokens.append((workspace, frontmost))
    }

    func stop() {
        for (center, token) in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
        pending?.cancel()
        pending = nil
    }

    private func check(_ onTrusted: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task {
            // The trust check lags the notification slightly: one short wait, not a polling loop.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, AXIsProcessTrusted() else { return }
            onTrusted()
        }
    }
}
