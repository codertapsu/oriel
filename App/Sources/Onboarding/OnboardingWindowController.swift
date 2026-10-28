import AppKit
import Permissions
import SwiftUI

/// First-launch permissions guide (PLAN §8.2). "Continue" never requires a permission: without one, the
/// matching feature runs degraded (icons-only switcher, no capture).
@MainActor
final class OnboardingWindowController {
    private let window: NSWindow

    init(permissions: PermissionCenter, onFinish: @escaping @MainActor () -> Void) {
        var close: (@MainActor () -> Void)?
        let view = OnboardingView(permissions: permissions) { close?() }
        window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Oriel"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        close = { [window] in
            window.close()
            onFinish()
        }
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
