import AppKit
import Observation
import SharedUI

/// Owns the overlay's two borderless panels: the frozen capture with translations over the captured area, and the
/// toolbar attached above or below it (PLAN §7.7.6, §10.5). Redraws whenever the session model changes, through
/// observation tracking rather than polling.
@MainActor
final class TranslationOverlayController {
    let model: TranslationSessionModel
    private let panel: FloatingPanel
    private let toolbarPanel: FloatingPanel
    private let overlayView: TranslationOverlayView
    private let toolbar: TranslationToolbar
    private var isClosed = false

    /// The overlay's frame in Cocoa screen coordinates.
    var frame: CGRect {
        panel.frame
    }

    var screen: NSScreen? {
        panel.screen
    }

    init(
        model: TranslationSessionModel,
        frame: CGRect,
        toolbarActions: TranslationToolbar.Actions,
        providerShortcut: @escaping @MainActor (Int) -> Void,
        copyBlock: @escaping @MainActor (TranslationBlock) -> Void
    ) {
        self.model = model
        panel = FloatingPanel(contentRect: frame, level: .statusBar, joinsAllSpaces: false)
        panel.allowsKey = true // Esc, ⌘1…⌘9 and ⌥ reach the overlay without activating Oriel
        panel.hasShadow = false
        overlayView = TranslationOverlayView(model: model)
        overlayView.onClose = toolbarActions.close
        overlayView.onProviderShortcut = providerShortcut
        overlayView.onCopyBlock = copyBlock
        panel.contentView = overlayView
        panel.setAccessibilityLabel("Translation")

        toolbarPanel = FloatingPanel(level: .statusBar, joinsAllSpaces: false)
        toolbar = TranslationToolbar(actions: toolbarActions)
        toolbarPanel.contentView = toolbar
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(overlayView)
        observe()
        placeToolbar()
        panel.addChildWindow(toolbarPanel, ordered: .above)
        toolbarPanel.orderFront(nil)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        panel.removeChildWindow(toolbarPanel)
        toolbarPanel.orderOut(nil)
        panel.orderOut(nil)
    }

    /// The annotated image as the overlay shows it, for "Export PNG".
    func annotatedImage() -> CGImage? {
        OverlayRenderer.annotatedImage(
            model.capture.image,
            layouts: overlayView.layouts(waitingForColors: false),
            pointSize: overlayView.bounds.size
        )
    }

    private func observe() {
        guard !isClosed else { return }
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func render() {
        toolbar.update(from: model)
        overlayView.refresh()
        _ = (model.blocks, model.colors, model.phase, model.note)
        placeToolbar()
    }

    private func placeToolbar() {
        let size = toolbar.fittingSize
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? panel.frame
        let frame = OverlayPlacement.toolbarFrame(size: size, overlay: panel.frame, visibleFrame: visible)
        if toolbarPanel.frame != frame {
            toolbarPanel.setFrame(frame, display: true)
        }
    }
}
