import AppKit

/// The scrolled document view holding the tiles, top-left origin like `SwitcherLayout`.
final class TileGridView: NSView {
    override var isFlipped: Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .group
    }

    override func accessibilityLabel() -> String? {
        "Windows"
    }
}
