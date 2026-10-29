import AppKit

/// An app's name over its windows in a switcher that groups by app: the app's icon and name in small secondary text,
/// with a hairline under it across the group's tiles in that row (a grid) or across the list. VoiceOver reads it as
/// a heading, so the windows that follow belong to it.
final class GroupHeaderView: NSView {
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let rule = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        nameField.font = .systemFont(ofSize: 11, weight: .semibold)
        nameField.textColor = .secondaryLabelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.maximumNumberOfLines = 1
        rule.boxType = .separator
        for view in [iconView, nameField, rule] as [NSView] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func configure(name: String, icon: NSImage?) {
        nameField.stringValue = name
        iconView.image = icon
        iconView.isHidden = icon == nil
        setAccessibilityLabel(name)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let side: CGFloat = 14
        let midY = bounds.height / 2 + 1
        iconView.frame = CGRect(x: 6, y: midY - side / 2, width: side, height: side)
        let textX = iconView.isHidden ? 6 : iconView.frame.maxX + 5
        nameField.frame = CGRect(x: textX, y: midY - 8, width: max(bounds.width - textX - 6, 0), height: 16)
        rule.frame = CGRect(x: 6, y: bounds.height - 1, width: max(bounds.width - 12, 0), height: 1)
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    /// `AXHeading`, new in macOS 26 (the deployment target); Swift spells it `.headingRole`, not `.heading`.
    override func accessibilityRole() -> NSAccessibility.Role? {
        .headingRole
    }
}
