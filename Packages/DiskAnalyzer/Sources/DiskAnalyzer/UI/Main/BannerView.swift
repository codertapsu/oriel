import AppKit

/// A note above the views, with the action that resolves it: folders that could not be read (Grant Full Disk
/// Access…), a scan that was stopped (Scan Again), what grew since the last scan (Show Changes).
final class BannerView: NSView {
    private let action: (() -> Void)?
    private let onClose: (() -> Void)?

    init(symbol: String, tint: NSColor, text: String, button: String?, action: (() -> Void)?, onClose: (() -> Void)? = nil) {
        self.action = action
        self.onClose = onClose
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = tint
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize + 1)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // The text takes the room, so every banner's button sits at the right edge.
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        var views: [NSView] = [icon, label]
        if let button {
            let control = NSButton(title: button, target: self, action: #selector(run))
            control.controlSize = .small
            control.bezelStyle = .push
            control.setContentHuggingPriority(.required, for: .horizontal)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
            views.append(control)
        }
        if onClose != nil {
            let close = NSButton(
                image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Hide") ?? NSImage(),
                target: self,
                action: #selector(closed)
            )
            close.isBordered = false
            close.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            close.contentTintColor = .tertiaryLabelColor
            close.toolTip = "Hide until the next scan"
            close.setContentHuggingPriority(.required, for: .horizontal)
            views.append(close)
        }
        let stack = NSStackView(views: views)
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 10, bottom: 7, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(text)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.quaternarySystemFill.cgColor
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    @objc private func run() {
        action?()
    }

    @objc private func closed() {
        onClose?()
    }
}
