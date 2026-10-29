import AppKit

/// One format in the list: its number key, its name and the value, which a click copies. A long value (the code
/// formats) wraps onto a second line rather than hiding its middle. The default format shows ⌘C, where the copy icon
/// appears on hover. After a copy the row says so for a moment.
final class FormatRowView: NSView {
    static let minimumHeight: CGFloat = 24

    let format: ColorFormat
    var onCopy: ((ColorFormat) -> Void)?

    private let keyLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(wrappingLabelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "⌘C")
    private let copyIcon = NSImageView()
    private var value = ""
    private var isDefault = false
    private var isHovered = false {
        didSet { updateBackground() }
    }

    private var isPressed = false {
        didSet { updateBackground() }
    }

    private var flashTask: Task<Void, Never>?

    init(format: ColorFormat) {
        self.format = format
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        keyLabel.stringValue = format.keyNumber.map(String.init) ?? ""
        keyLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        keyLabel.textColor = .tertiaryLabelColor
        keyLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        valueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .labelColor
        valueLabel.maximumNumberOfLines = 2
        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.cell?.truncatesLastVisibleLine = true
        valueLabel.isSelectable = false
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        shortcutLabel.font = .systemFont(ofSize: 10, weight: .medium)
        shortcutLabel.textColor = .tertiaryLabelColor
        shortcutLabel.alignment = .right
        copyIcon.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyIcon.contentTintColor = .secondaryLabelColor
        copyIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        layOut()
        updateBackground()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String, value: String, isDefault: Bool) {
        titleLabel.stringValue = title
        self.value = value
        self.isDefault = isDefault
        if flashTask == nil {
            showValue()
        }
        updateBackground()
        let key = format.keyNumber.map { ", key \($0)" } ?? ""
        setAccessibilityLabel("Copy \(title)\(isDefault ? ", Command-C" : "")\(key)")
        setAccessibilityValue(value)
        toolTip = "Copy \(value)"
    }

    /// "Copied" in place of the value, for a moment.
    func flashCopied() {
        flashTask?.cancel()
        valueLabel.stringValue = "Copied"
        valueLabel.textColor = .controlAccentColor
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.flashTask = nil
            self?.showValue()
        }
    }

    private func showValue() {
        valueLabel.stringValue = value
        valueLabel.textColor = .labelColor
    }

    /// A wrapping label needs its width to know its height.
    override func layout() {
        super.layout()
        let width = valueLabel.frame.width
        if width > 0, valueLabel.preferredMaxLayoutWidth != width {
            valueLabel.preferredMaxLayoutWidth = width
            valueLabel.invalidateIntrinsicContentSize()
        }
    }

    // MARK: Mouse

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    /// A row is a button: a press on it copies rather than moving the panel.
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        isPressed = false
    }

    override func mouseDown(with _: NSEvent) {
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside {
            onCopy?(format)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onCopy?(format)
        return true
    }

    private func updateBackground() {
        let fill: NSColor? = isPressed ? .tertiaryLabelColor.withAlphaComponent(0.25) : (isHovered ? .quaternaryLabelColor : nil)
        layer?.backgroundColor = fill?.cgColor
        copyIcon.isHidden = !isHovered
        shortcutLabel.isHidden = !isDefault || isHovered
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func layOut() {
        for view in [keyLabel, titleLabel, valueLabel, shortcutLabel, copyIcon] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // As short as the value allows: without this the height would only be bounded from below.
        let compact = heightAnchor.constraint(equalToConstant: Self.minimumHeight)
        compact.priority = .defaultLow
        NSLayoutConstraint.activate([
            compact,
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumHeight),
            valueLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4),
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            keyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            keyLabel.widthAnchor.constraint(equalToConstant: 14),
            keyLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 6),
            titleLabel.widthAnchor.constraint(equalToConstant: 80),
            titleLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            shortcutLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),
            copyIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            copyIcon.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            copyIcon.widthAnchor.constraint(equalToConstant: 14),
        ])
    }
}
