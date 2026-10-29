import AppKit

/// A plain container with its origin at the top-left, so a scroll view's content starts at the top.
final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
