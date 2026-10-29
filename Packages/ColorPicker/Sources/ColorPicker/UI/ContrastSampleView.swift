import AppKit

/// The two colors as they would be used: body text, large text (24 pt, WCAG's 18 pt) and a control drawn in the text
/// color on the background.
final class ContrastSampleView: NSView {
    private var text: ColorValue = .black
    private var background: ColorValue = .white

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Sample text in the text color on the background")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(text: ColorValue, background: ColorValue) {
        self.text = text
        self.background = background
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        let backgroundColor = background.clamped
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        ColorValue(red: backgroundColor.red, green: backgroundColor.green, blue: backgroundColor.blue).nsColor.setFill()
        shape.fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()

        let ink = text.nsColor
        let left: CGFloat = 14
        draw("Large text, 24 pt", font: .systemFont(ofSize: 24, weight: .regular), color: ink, at: CGPoint(x: left, y: bounds.maxY - 40))
        let body = "Body text at 14 pt, the size most interfaces use for reading."
        let bodyRect = CGRect(x: left, y: bounds.maxY - 82, width: bounds.width - 2 * left, height: 36)
        (body as NSString).draw(
            with: bodyRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: ink]
        )

        // A button outline and an icon: the non-text contrast of SC 1.4.11.
        let button = CGRect(x: left, y: 12, width: 92, height: 26)
        let outline = NSBezierPath(roundedRect: button.insetBy(dx: 0.75, dy: 0.75), xRadius: 7, yRadius: 7)
        outline.lineWidth = 1.5
        ink.setStroke()
        outline.stroke()
        let title = "Button" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: ink]
        let size = title.size(withAttributes: attributes)
        title.draw(at: CGPoint(x: button.midX - size.width / 2, y: button.midY - size.height / 2), withAttributes: attributes)
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium).applying(.init(paletteColors: [ink]))
        for (index, symbol) in ["star.fill", "bell", "checkmark.circle"].enumerated() {
            guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
            else {
                continue
            }
            let origin = CGPoint(x: button.maxX + 16 + CGFloat(index) * 30, y: button.midY - image.size.height / 2)
            image.draw(in: CGRect(origin: origin, size: image.size))
        }
    }

    private func draw(_ string: String, font: NSFont, color: NSColor, at point: CGPoint) {
        (string as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }
}
