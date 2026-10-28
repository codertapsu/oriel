import AppKit
import SwiftUI

/// Hosts the SwiftUI side panel in a small utility panel that floats beside the overlay without activating Oriel.
@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    var onClose: (@MainActor () -> Void)?

    var isVisible: Bool {
        panel.isVisible
    }

    init(model: TranslationSessionModel, actions: TranslationPanelView.Actions) {
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.title = "Translation"
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.contentView = NSHostingView(rootView: TranslationPanelView(model: model, actions: actions))
        panel.delegate = self
    }

    /// Shows the panel beside `overlay` (Cocoa coordinates), or centred on the screen when there is no overlay.
    func show(beside overlay: CGRect?, on screen: NSScreen?) {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? .zero
        if let overlay, !visible.isEmpty {
            panel.setFrame(OverlayPlacement.sidePanelFrame(size: panel.frame.size, overlay: overlay, visibleFrame: visible), display: false)
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    nonisolated func windowWillClose(_: Notification) {
        MainActor.assumeIsolated {
            onClose?()
        }
    }
}
