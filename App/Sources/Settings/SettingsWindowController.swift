import AppKit
import SwiftUI

/// The Settings window: SwiftUI panes hosted in an AppKit window (PLAN §10.1).
@MainActor
final class SettingsWindowController {
    private let window: NSWindow
    private let navigation = SettingsNavigation()

    init(controller: AppController) {
        let view = SettingsView(controller: controller, navigation: navigation)
        window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Oriel Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show(tab: String?) {
        if let tab {
            navigation.tab = tab
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
