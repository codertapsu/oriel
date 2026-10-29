import AppKit

/// A flipped document view, so a scroll view's content starts at the top.
final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
