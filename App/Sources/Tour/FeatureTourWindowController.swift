import AppKit
import SwiftUI

/// The feature tour's window (PLAN §19): SwiftUI pages hosted in an AppKit window, like Settings.
@MainActor
final class FeatureTourWindowController {
    private let window: NSWindow

    init(controller: AppController) {
        window = NSWindow(contentViewController: NSHostingController(rootView: FeatureTourView(controller: controller)))
        window.title = "Oriel Feature Tour"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 860, height: 600))
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
