import AppKit
import SwiftUI

/// The window that hosts `HistoryView`. Created on first use and kept, so its size and place are remembered.
final class HistoryWindowController {
    private static let autosaveName = "OrielCaptureHistory"
    private var window: NSWindow?

    func show(_ model: HistoryModel) {
        let window = window ?? makeWindow(model)
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(_ model: HistoryModel) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 880, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Capture History"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: HistoryView(model: model))
        if !window.setFrameUsingName(Self.autosaveName) {
            window.setContentSize(CGSize(width: 880, height: 600))
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
        return window
    }
}
