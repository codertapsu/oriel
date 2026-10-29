import AppKit

/// The latest picks in a row, newest first, scrolling sideways when they do not fit. A click makes one the current
/// color; right-click for the rest.
final class RecentColorsView: NSView {
    static let swatchSide: CGFloat = 22

    var onSelect: ((Int) -> Void)?
    var makeMenu: ((Int) -> NSMenu?)?

    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "Colors you pick appear here.")
    private var swatches: [SwatchButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.verticalScrollElasticity = .none
        scroll.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.swatchSide + 4),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            document.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            document.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
            stack.centerYAnchor.constraint(equalTo: document.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Recent colors")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ colors: [ColorValue], selected: ColorValue?, uppercaseHex: Bool) {
        while swatches.count > colors.count {
            swatches.removeLast().removeFromSuperview()
        }
        while swatches.count < colors.count {
            let swatch = SwatchButton(color: .white, side: Self.swatchSide)
            let index = swatches.count
            swatch.onClick = { [weak self] in self?.onSelect?(index) }
            swatch.makeMenu = { [weak self] in self?.makeMenu?(index) }
            stack.addArrangedSubview(swatch)
            swatches.append(swatch)
        }
        var selectedShown = false
        for (swatch, color) in zip(swatches, colors) {
            swatch.color = color
            swatch.uppercaseHex = uppercaseHex
            // Only the first match is marked, so a color listed once is selected once.
            let isSelected = !selectedShown && selected.map(color.isSameColor) == true
            swatch.isSelected = isSelected
            selectedShown = selectedShown || isSelected
        }
        emptyLabel.isHidden = !colors.isEmpty
    }
}
