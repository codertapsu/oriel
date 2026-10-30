import AppKit

/// The preview's content, laid out from the top, which tells when the pointer enters and leaves it.
final class DockPreviewContentView: NSView {
    var onPointerInside: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with _: NSEvent) {
        onPointerInside?(true)
    }

    override func mouseExited(with _: NSEvent) {
        onPointerInside?(false)
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .group
    }
}
