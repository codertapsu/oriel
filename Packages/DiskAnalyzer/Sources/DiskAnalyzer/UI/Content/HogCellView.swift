import AppKit

/// A space hog's row: its icon, its name, and what it is in a line or two, with whether it comes back by itself.
final class HogCellView: NSTableCellView {
    init(hog: SpaceHog) {
        super.init(frame: .zero)
        let icon = NSImageView(image: NSImage(systemSymbolName: hog.symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.contentTintColor = hog.isRebuilt ? .systemGreen : .systemOrange
        let title = NSTextField(labelWithString: hog.title)
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        let detail = NSTextField(wrappingLabelWithString: hog.detail)
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 2
        detail.lineBreakMode = .byWordWrapping
        detail.cell?.truncatesLastVisibleLine = true
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let texts = NSStackView(views: [title, detail])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        let stack = NSStackView(views: [icon, texts])
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
        ])
        icon.setAccessibilityLabel(hog.isRebuilt ? "Comes back by itself" : "Review before removing")
        setAccessibilityLabel("\(hog.title). \(hog.detail)")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
