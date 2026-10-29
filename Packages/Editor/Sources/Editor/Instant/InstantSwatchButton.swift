import AppKit

/// One palette colour in Instant Capture's colour popover, ringed in the accent colour when it is the current one.
final class InstantSwatchButton: NSButton {
    let swatch: RGBAColor
    var isCurrent = false {
        didSet {
            setAccessibilityValue(isCurrent ? "Selected" : nil)
            needsDisplay = true
        }
    }

    init(color: RGBAColor, name: String, target: AnyObject, action: Selector) {
        swatch = color
        super.init(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        toolTip = name
        setAccessibilityLabel(name)
        self.target = target
        self.action = action
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 26).isActive = true
        heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_: NSRect) {
        let circle = CGRect(x: bounds.midX - 10, y: bounds.midY - 10, width: 20, height: 20)
        swatch.nsColor.setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5)).stroke()
        if isCurrent {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(ovalIn: circle.insetBy(dx: -2.5, dy: -2.5))
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}
