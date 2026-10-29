import AppKit

/// A step's number in a circle of the accent colour, as the exports show it.
final class StepNumberBadge: NSView {
    static let diameter: CGFloat = 26

    var number = 1 {
        didSet {
            needsDisplay = true
            setAccessibilityLabel("Step \(number)")
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Step 1")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.diameter, height: Self.diameter)
    }

    override func draw(_: CGRect) {
        let circle = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: circle).fill()
        let font = NSFont.monospacedDigitSystemFont(ofSize: number < 100 ? 13 : 10, weight: .bold)
        let text = "\(number)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}
