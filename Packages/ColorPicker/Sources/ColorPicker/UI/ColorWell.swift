import AppKit

/// A swatch that takes a dropped color, from the panel or another app: the contrast checker's two colors.
final class ColorWell: NSView {
    var color: ColorValue = .black {
        didSet { needsDisplay = true }
    }

    var onDrop: ((ColorValue) -> Void)?
    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    init(side: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: side), heightAnchor.constraint(equalToConstant: side)])
        registerForDraggedTypes(ColorDrop.types)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_: NSRect) {
        SwatchDrawing.draw(color, in: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6)
        if isTargeted {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard ColorDrop(sender.draggingPasteboard) != nil else { return [] }
        isTargeted = true
        return .copy
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        isTargeted = false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isTargeted = false
        guard let drop = ColorDrop(sender.draggingPasteboard) else { return false }
        onDrop?(drop.color)
        return true
    }
}
