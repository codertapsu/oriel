import AppKit

/// A clip view that keeps a document smaller than itself centred instead of pinned to a corner.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }
        let document = documentView.frame
        if rect.width > document.width {
            rect.origin.x = document.minX - (rect.width - document.width) / 2
        }
        if rect.height > document.height {
            rect.origin.y = document.minY - (rect.height - document.height) / 2
        }
        return rect
    }
}
