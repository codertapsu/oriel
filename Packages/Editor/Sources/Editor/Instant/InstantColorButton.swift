import AppKit

/// The current colour as a round swatch in Instant Capture's toolbar; clicking it opens the colour and width popover.
final class InstantColorButton: NSButton {
    var color: RGBAColor = .red {
        didSet {
            setAccessibilityValue(color.paletteName ?? "Custom")
            needsDisplay = true
        }
    }

    private let handler: @MainActor (NSView) -> Void

    init(handler: @escaping @MainActor (NSView) -> Void) {
        self.handler = handler
        super.init(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        toolTip = "Colour and width"
        setAccessibilityLabel("Colour and width")
        target = self
        action = #selector(run)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 28).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func draw(_: NSRect) {
        let swatch = CGRect(x: bounds.midX - 9, y: bounds.midY - 9, width: 18, height: 18)
        color.nsColor.setFill()
        NSBezierPath(ovalIn: swatch).fill()
        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
        let ring = NSBezierPath(ovalIn: swatch.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()
    }

    @objc private func run() {
        handler(self)
    }
}
