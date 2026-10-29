import AppKit

/// One item of the list: a thumbnail, file icon, color swatch or kind symbol; the title; the source app and when it
/// was copied; a pin for pinned items and the ⌘-number of the first nine.
final class ClipboardRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("ClipboardRow")
    static let height: CGFloat = 46

    private let iconView = NSImageView()
    private let swatch = NSView()
    private let titleField = NSTextField(labelWithString: "")
    private let appIconView = NSImageView()
    private let detailField = NSTextField(labelWithString: "")
    private let pinView = NSImageView()
    private let numberField = NSTextField(labelWithString: "")
    private(set) var itemID: UUID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 5
        iconView.layer?.masksToBounds = true
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 7
        swatch.layer?.borderWidth = 1
        titleField.font = .systemFont(ofSize: 13)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        detailField.font = .systemFont(ofSize: 11)
        detailField.lineBreakMode = .byTruncatingTail
        detailField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pinView.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned")
        pinView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        numberField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        numberField.alignment = .right
        textField = titleField
        layOut()
        applyColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ item: ClipboardItem, isPinned: Bool, number: Int?, appIcon: NSImage?, image: NSImage?, now: Date) {
        itemID = item.id
        titleField.stringValue = item.title
        let source = item.sourceName.map { "\($0) · " } ?? ""
        detailField.stringValue = source + ClipboardFormat.relativeTime(item.lastCopied, now: now)
        appIconView.image = appIcon
        appIconView.isHidden = appIcon == nil
        pinView.isHidden = !isPinned
        numberField.stringValue = number.map { "⌘\($0)" } ?? ""
        if let hex = item.colorHex, let color = ClipboardColor(parsing: hex) {
            swatch.isHidden = false
            iconView.isHidden = true
            swatch.layer?.backgroundColor = CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        } else {
            swatch.isHidden = true
            iconView.isHidden = false
            setIcon(
                image ?? NSImage(systemSymbolName: item.kind.symbol, accessibilityDescription: item.kind.displayName),
                isPicture: image != nil
            )
        }
        let pinned = isPinned ? ", pinned" : ""
        setAccessibilityLabel("\(item.kind.displayName): \(item.title). \(detailField.stringValue)\(pinned)")
    }

    /// A thumbnail that arrived after the row was drawn.
    func setThumbnail(_ image: NSImage) {
        setIcon(image, isPicture: true)
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { applyColors() }
    }

    private func setIcon(_ image: NSImage?, isPicture: Bool) {
        iconView.image = image
        iconView.symbolConfiguration = isPicture ? nil : NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        iconView.layer?.borderWidth = isPicture ? 0.5 : 0
        iconView.imageScaling = isPicture ? .scaleProportionallyUpOrDown : .scaleNone
    }

    /// Selected rows are drawn on the accent color, so the secondary text turns light with them.
    private func applyColors() {
        let emphasized = backgroundStyle == .emphasized
        titleField.textColor = emphasized ? .alternateSelectedControlTextColor : .labelColor
        detailField.textColor = emphasized ? .alternateSelectedControlTextColor.withAlphaComponent(0.8) : .secondaryLabelColor
        numberField.textColor = emphasized ? .alternateSelectedControlTextColor.withAlphaComponent(0.8) : .tertiaryLabelColor
        pinView.contentTintColor = emphasized ? .alternateSelectedControlTextColor : .systemOrange
        iconView.contentTintColor = emphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
        iconView.layer?.borderColor = NSColor.separatorColor.cgColor
        swatch.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func layOut() {
        let titleRow = NSStackView(views: [titleField, pinView])
        titleRow.spacing = 4
        let detailRow = NSStackView(views: [appIconView, detailField])
        detailRow.spacing = 4
        let texts = NSStackView(views: [titleRow, detailRow])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 2
        for view in [iconView, swatch, texts, numberField] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 30),
            iconView.heightAnchor.constraint(equalToConstant: 30),
            swatch.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            swatch.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 24),
            swatch.heightAnchor.constraint(equalToConstant: 24),
            texts.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 9),
            texts.centerYAnchor.constraint(equalTo: centerYAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: numberField.leadingAnchor, constant: -6),
            appIconView.widthAnchor.constraint(equalToConstant: 13),
            appIconView.heightAnchor.constraint(equalToConstant: 13),
            numberField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            numberField.centerYAnchor.constraint(equalTo: centerYAnchor),
            numberField.widthAnchor.constraint(equalToConstant: 28),
        ])
    }
}
