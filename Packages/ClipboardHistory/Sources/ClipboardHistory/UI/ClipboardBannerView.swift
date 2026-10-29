import AppKit

/// A line under the search field when something needs the user: Clipboard History is paused, macOS keeps Oriel from
/// reading other apps' copies, or pasting needs Accessibility.
final class ClipboardBannerView: NSView {
    /// What the banner says and offers.
    struct Message: Equatable {
        let symbol: String
        let text: String
        let action: String?
    }

    var onAction: (() -> Void)?

    private let icon = NSImageView()
    private let textField = NSTextField(wrappingLabelWithString: "")
    private let button = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.14).cgColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        icon.contentTintColor = .systemOrange
        icon.setContentHuggingPriority(.required, for: .horizontal)
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = .labelColor
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.bezelStyle = .push
        button.controlSize = .small
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.target = self
        button.action = #selector(pressed)
        let stack = NSStackView(views: [icon, textField, button])
        stack.spacing = 8
        stack.alignment = .centerY
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ message: Message) {
        icon.image = NSImage(systemSymbolName: message.symbol, accessibilityDescription: nil)
        textField.stringValue = message.text
        button.title = message.action ?? ""
        button.isHidden = message.action == nil
        setAccessibilityLabel(message.text)
    }

    @objc private func pressed() {
        onAction?()
    }
}
