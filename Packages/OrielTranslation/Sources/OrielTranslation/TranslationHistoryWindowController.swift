import AppKit
import SwiftUI

/// The history window. Oriel has no Dock icon, so showing a regular window activates the app first.
@MainActor
final class TranslationHistoryWindowController {
    private let model: TranslationHistoryModel
    private var window: NSWindow?

    init(model: TranslationHistoryModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        Task { await model.reload() }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: TranslationHistoryView(model: model)))
        window.title = "Translation History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 760, height: 480))
        window.setFrameAutosaveName("TranslationHistory")
        return window
    }
}
