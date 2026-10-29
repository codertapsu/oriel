import AppKit

/// A color to click, drag or right-click: the swatches of the recent strip and of the palettes. A drag carries the
/// color as HEX text and as an `NSColor`, so it drops into other apps too, and, for a palette color, its entry, so a
/// drop within the panel moves it instead of copying it.
final class SwatchButton: NSView, NSDraggingSource {
    /// Marks a drag of a palette entry within the panel; the data is the entry's UUID.
    static let paletteColorType = NSPasteboard.PasteboardType("com.codertapsu.oriel.palette-color")

    var color: ColorValue {
        didSet {
            needsDisplay = true
            updateAccessibility()
        }
    }

    /// The palette entry it shows; nil for a recent color.
    var paletteColorID: UUID?
    var name: String? {
        didSet { updateAccessibility() }
    }

    var isSelected = false {
        didSet { needsDisplay = true }
    }

    var uppercaseHex = true {
        didSet { updateAccessibility() }
    }

    var onClick: (() -> Void)?
    var makeMenu: (() -> NSMenu?)?

    private let side: CGFloat
    private var pressedAt: CGPoint?
    private var isDragging = false

    init(color: ColorValue, side: CGFloat) {
        self.color = color
        self.side = side
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: side), heightAnchor.constraint(equalToConstant: side)])
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: side, height: side)
    }

    override func draw(_: NSRect) {
        let inset: CGFloat = isSelected ? 3 : 0.5
        SwatchDrawing.draw(color, in: bounds.insetBy(dx: inset, dy: inset), cornerRadius: max(2, side * 0.22 - inset))
        if isSelected {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: side * 0.26, yRadius: side * 0.26)
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    /// The panel rarely is the key window, and the first click must still pick the swatch.
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    /// The panel moves by its background; a drag that starts on a swatch carries the color instead.
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        pressedAt = convert(event.locationInWindow, from: nil)
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressedAt, !isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - pressedAt.x, point.y - pressedAt.y) > 3 else { return }
        isDragging = true
        beginDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressedAt = nil }
        guard !isDragging, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick?()
    }

    override func menu(for _: NSEvent) -> NSMenu? {
        makeMenu?()
    }

    // MARK: Dragging

    private func beginDrag(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(color.hex(uppercase: uppercaseHex, includesAlpha: !color.isOpaque), forType: .string)
        if let archived = color.nsColor.pasteboardPropertyList(forType: .color) {
            item.setPropertyList(archived, forType: .color)
        }
        if let paletteColorID {
            item.setString(paletteColorID.uuidString, forType: Self.paletteColorType)
        }
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [dragging], event: event, source: self)
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.move, .copy] : .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        isDragging = false
        pressedAt = nil
    }

    private func snapshot() -> NSImage {
        NSImage(size: bounds.size, flipped: false) { [color, side] rect in
            SwatchDrawing.draw(color, in: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: side * 0.22)
            return true
        }
    }

    // MARK: Accessibility

    private func updateAccessibility() {
        let hex = color.hex(uppercase: uppercaseHex, includesAlpha: !color.isOpaque)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(name.map { "\($0), \(hex)" } ?? hex)
        toolTip = name.map { "\($0) · \(hex)" } ?? hex
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}
