import AppKit

/// A document view with its origin at the top, so a short page sits at the top of its scroll view.
final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
