import AppKit

/// A symbol button for Instant Capture's toolbar that can show itself selected (the current tool): tinted with the
/// accent colour on a soft accent background, as the editor's tool strip does. Takes the first click, since the
/// toolbar's panel never becomes key.
final class InstantToolButton: NSButton {
    var isChosen = false {
        didSet {
            contentTintColor = isChosen ? .controlAccentColor : .labelColor
            setAccessibilityValue(isChosen ? "Selected" : nil)
            needsDisplay = true
        }
    }

    private let handler: @MainActor () -> Void

    init(symbol: String, label: String, help: String? = nil, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        imagePosition = .imageOnly
        isBordered = false
        bezelStyle = .regularSquare
        contentTintColor = .labelColor
        toolTip = help ?? label
        setAccessibilityLabel(label)
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

    override func draw(_ dirtyRect: NSRect) {
        if isChosen {
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }

    @objc private func run() {
        handler()
    }
}
