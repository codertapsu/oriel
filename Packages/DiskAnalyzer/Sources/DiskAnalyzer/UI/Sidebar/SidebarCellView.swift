import AppKit

/// A sidebar row: an icon, the name, a line of detail and, for a volume, its capacity bar.
final class SidebarCellView: NSTableCellView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let bar = CapacityBarView()
    private let stack: NSStackView

    override init(frame: NSRect) {
        let texts = NSStackView(views: [title, bar, detail])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 3
        stack = NSStackView(views: [icon, texts])
        stack.alignment = .centerY
        stack.spacing = 8
        super.init(frame: frame)
        title.font = .systemFont(ofSize: NSFont.systemFontSize)
        title.lineBreakMode = .byTruncatingTail
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        textField = title
        imageView = icon
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            bar.widthAnchor.constraint(equalTo: texts.widthAnchor),
            texts.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -30),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A selected row in a key window has an accent background: the detail and the bar turn light to stay readable.
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            let emphasized = backgroundStyle == .emphasized
            detail.textColor = emphasized ? NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.8) : .secondaryLabelColor
            icon.contentTintColor = emphasized ? .alternateSelectedControlTextColor : .controlAccentColor
            bar.isEmphasized = emphasized
        }
    }

    func show(symbol: String, title text: String, detail line: String, usage: VolumeUsage?) {
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        title.stringValue = text
        detail.stringValue = line
        detail.isHidden = line.isEmpty
        bar.usage = usage
        bar.isHidden = usage == nil
        setAccessibilityLabel(line.isEmpty ? text : "\(text), \(line)")
    }
}
