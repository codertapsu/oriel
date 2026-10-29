import AppKit

/// The notice's content: the Accessibility symbol, what is missing, where to turn it on, and a button that opens the
/// pane. Laid out by hand from the wrapped message's height, so the notice is exactly as tall as its text.
final class PermissionNoticeView: NSView {
    static let title = "Window Tiling needs Accessibility"

    private static let textWidth: CGFloat = 290
    private static let insets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
    private static let iconSide: CGFloat = 28

    private let onOpen: @MainActor () -> Void
    private let icon = NSImageView()
    private let titleField = NSTextField(labelWithString: PermissionNoticeView.title)
    private let messageField: NSTextField
    private let button = FirstClickButton(title: "Open System Settings", target: nil, action: nil)

    init(paneName: String, onOpen: @escaping @MainActor () -> Void) {
        self.onOpen = onOpen
        messageField = NSTextField(wrappingLabelWithString: Self.message(paneName: paneName))
        super.init(frame: .zero)
        icon.image = NSImage(systemSymbolName: "accessibility", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        messageField.font = .systemFont(ofSize: 12)
        messageField.textColor = .secondaryLabelColor
        messageField.preferredMaxLayoutWidth = Self.textWidth
        button.bezelStyle = .push
        button.keyEquivalent = "\r"
        button.target = self
        button.action = #selector(open)
        for view in [icon, titleField, messageField, button] as [NSView] {
            addSubview(view)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("\(Self.title). \(Self.message(paneName: paneName))")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    /// Where to turn it on; macOS 27 calls the pane Device Control and Data Access.
    static func message(paneName: String) -> String {
        "Switch Oriel on in System Settings → Privacy & Security → \(paneName)."
    }

    override var intrinsicContentSize: NSSize {
        let insets = Self.insets
        let button = button.fittingSize
        let width = insets.left + Self.iconSide + 12 + Self.textWidth + 16 + button.width + insets.right
        let height = insets.top + max(textHeight, button.height, Self.iconSide) + insets.bottom
        return NSSize(width: width.rounded(.up), height: height.rounded(.up))
    }

    override func layout() {
        super.layout()
        let insets = Self.insets
        let midY = bounds.height / 2
        icon.frame = CGRect(x: insets.left, y: midY - Self.iconSide / 2, width: Self.iconSide, height: Self.iconSide)
        let textX = icon.frame.maxX + 12
        let titleHeight = titleField.intrinsicContentSize.height
        let top = midY - textHeight / 2
        titleField.frame = CGRect(x: textX, y: top, width: Self.textWidth, height: titleHeight)
        messageField.frame = CGRect(x: textX, y: top + titleHeight + 2, width: Self.textWidth, height: messageHeight)
        let size = button.fittingSize
        button.frame = CGRect(
            x: bounds.width - insets.right - size.width,
            y: midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// The title and the message wrapped at `textWidth`.
    private var textHeight: CGFloat {
        titleField.intrinsicContentSize.height + 2 + messageHeight
    }

    private var messageHeight: CGFloat {
        let bounds = CGRect(x: 0, y: 0, width: Self.textWidth, height: 1000)
        return (messageField.cell?.cellSize(forBounds: bounds).height ?? 32).rounded(.up)
    }

    @objc private func open() {
        onOpen()
    }
}

/// A button that takes the click even though its panel never becomes key, so one click opens System Settings.
private final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
