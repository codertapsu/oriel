import AppKit
import SwiftUI

/// Shows `LanguagePackDownloadView` in a small window when a translation needs a pack that is not installed. The
/// system's download prompt needs a real window and an active app, so this one activates Oriel.
@MainActor
final class LanguagePackWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var completion: (@MainActor (Bool) -> Void)?

    func present(source: String, target: String, completion: @escaping @MainActor (Bool) -> Void) {
        finish(false)
        self.completion = completion
        let view = LanguagePackDownloadView(source: source, target: target, allowsChoosingLanguages: false) { [weak self] downloaded in
            self?.finish(downloaded)
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Language Pack"
        window.styleMask = [.titled, .closable]
        window.level = .modalPanel
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        NSApp.activate()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    nonisolated func windowWillClose(_: Notification) {
        MainActor.assumeIsolated {
            finish(false)
        }
    }

    private func finish(_ downloaded: Bool) {
        let completion = completion
        self.completion = nil
        if let window {
            self.window = nil
            window.delegate = nil
            window.close()
        }
        completion?(downloaded)
    }
}
