import AppKit

/// A small capsule label: a window's state ("Minimized", "Space 3") or an app's window count.
final class BadgeView: NSView {
    enum Style {
        /// White on translucent black, over thumbnails and icons.
        case overlay
        /// Secondary text on a faint fill, in title rows.
        case inline
        /// White on red, for window counts.
        case count
    }

    private static let font = NSFont.systemFont(ofSize: 10, weight: .semibold)

    var text = "" {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    var style: Style {
        didSet { needsDisplay = true }
    }

    /// Increase Contrast: a 1 px outline.
    var hasOutline = false {
        didSet { needsDisplay = true }
    }

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        let size = (text as NSString).size(withAttributes: [.font: Self.font])
        return NSSize(width: max(16, ceil(size.width) + 10), height: 16)
    }

    override func draw(_: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        let (fill, textColor): (NSColor, NSColor) = switch style {
        case .overlay: (NSColor.black.withAlphaComponent(0.6), .white)
        case .inline: (NSColor.quaternaryLabelColor, .secondaryLabelColor)
        case .count: (NSColor.systemRed, .white)
        }
        fill.setFill()
        path.fill()
        if hasOutline {
            NSColor.labelColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: textColor]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
    }

    override func isAccessibilityElement() -> Bool {
        false
    }
}
