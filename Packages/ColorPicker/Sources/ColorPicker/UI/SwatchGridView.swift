import AppKit

/// A palette's colors in rows that wrap, ending with a + tile that adds the current color. Swatches drag to another
/// place, or into another palette; a color dropped from elsewhere is added where it lands, at the marked gap.
final class SwatchGridView: NSView {
    static let side: CGFloat = 28
    static let gap: CGFloat = 6

    var onAdd: (() -> Void)?
    var onSelect: ((UUID) -> Void)?
    var makeMenu: ((UUID) -> NSMenu?)?
    /// A drop at an insertion index (0…count); returns whether it was taken.
    var onDrop: ((ColorDrop, Int) -> Bool)?

    private var swatches: [SwatchButton] = []
    private let addButton = NSButton()
    private var heightConstraint: NSLayoutConstraint?
    private var dropIndex: Int? {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add the current color")
        addButton.isBordered = false
        addButton.imagePosition = .imageOnly
        addButton.contentTintColor = .secondaryLabelColor
        addButton.toolTip = "Add the current color"
        addButton.target = self
        addButton.action = #selector(addClicked)
        addSubview(addButton)
        let height = heightAnchor.constraint(equalToConstant: Self.side)
        height.isActive = true
        heightConstraint = height
        registerForDraggedTypes(ColorDrop.types)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func show(_ colors: [PaletteColor], selected: UUID?, uppercaseHex: Bool) {
        while swatches.count > colors.count {
            swatches.removeLast().removeFromSuperview()
        }
        while swatches.count < colors.count {
            let swatch = SwatchButton(color: .white, side: Self.side)
            swatch.translatesAutoresizingMaskIntoConstraints = true
            swatch.onClick = { [weak self, weak swatch] in
                guard let id = swatch?.paletteColorID else { return }
                self?.onSelect?(id)
            }
            swatch.makeMenu = { [weak self, weak swatch] in
                guard let id = swatch?.paletteColorID else { return nil }
                return self?.makeMenu?(id)
            }
            addSubview(swatch)
            swatches.append(swatch)
        }
        for (swatch, entry) in zip(swatches, colors) {
            swatch.color = entry.color
            swatch.name = entry.name
            swatch.paletteColorID = entry.id
            swatch.uppercaseHex = uppercaseHex
            swatch.isSelected = entry.id == selected
        }
        needsLayout = true
    }

    // MARK: Layout

    private var columns: Int {
        max(1, Int((bounds.width + Self.gap) / (Self.side + Self.gap)))
    }

    private func origin(of index: Int) -> CGPoint {
        let step = Self.side + Self.gap
        return CGPoint(x: CGFloat(index % columns) * step, y: CGFloat(index / columns) * step)
    }

    override func layout() {
        super.layout()
        for (index, swatch) in swatches.enumerated() {
            swatch.frame = CGRect(origin: origin(of: index), size: CGSize(width: Self.side, height: Self.side))
        }
        addButton.frame = CGRect(origin: origin(of: swatches.count), size: CGSize(width: Self.side, height: Self.side))
        let rows = (swatches.count + 1 + columns - 1) / columns
        let height = CGFloat(rows) * (Self.side + Self.gap) - Self.gap
        if heightConstraint?.constant != height {
            heightConstraint?.constant = height
        }
    }

    override func draw(_: NSRect) {
        let tile = addButton.frame.insetBy(dx: 1, dy: 1)
        let outline = NSBezierPath(roundedRect: tile, xRadius: Self.side * 0.22, yRadius: Self.side * 0.22)
        outline.setLineDash([3, 2], count: 2, phase: 0)
        outline.lineWidth = 1
        NSColor.tertiaryLabelColor.setStroke()
        outline.stroke()
        if let dropIndex {
            let point = origin(of: dropIndex)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(
                roundedRect: CGRect(x: point.x - Self.gap / 2 - 1, y: point.y, width: 2, height: Self.side),
                xRadius: 1,
                yRadius: 1
            )
            .fill()
        }
    }

    @objc private func addClicked() {
        onAdd?()
    }

    // MARK: Dropping

    /// The gap nearest `point`: before the swatch it is over, or after it past its middle.
    private func insertionIndex(at point: CGPoint) -> Int {
        let step = Self.side + Self.gap
        let row = max(0, Int(point.y / step))
        let column = min(columns, max(0, Int((point.x + Self.gap / 2 + Self.side / 2) / step)))
        return min(swatches.count, row * columns + column)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let drop = ColorDrop(sender.draggingPasteboard) else {
            dropIndex = nil
            return []
        }
        dropIndex = insertionIndex(at: convert(sender.draggingLocation, from: nil))
        if case .paletteColor = drop, sender.draggingSourceOperationMask.contains(.move) {
            return .move
        }
        return .copy
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        dropIndex = nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        defer { dropIndex = nil }
        guard let drop = ColorDrop(sender.draggingPasteboard) else { return false }
        return onDrop?(drop, insertionIndex(at: convert(sender.draggingLocation, from: nil))) ?? false
    }
}
