import AppKit
import SharedUI

/// An app tile: the icon with a window-count badge, the app's name below, and the first state badge of its
/// most recent window.
final class AppIconTileView: TileView {
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let countBadge = BadgeView(style: .count)
    private let badges = BadgeStack(style: .overlay)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        nameField.alignment = .center
        nameField.lineBreakMode = .byTruncatingTail
        nameField.maximumNumberOfLines = 1
        for view in [iconView, nameField, badges, countBadge] as [NSView] {
            addSubview(view)
        }
        bringActionBarToFront()
    }

    override func configure(_ item: SwitcherItem, icon: NSImage?, display: AccessibilityDisplay) {
        super.configure(item, icon: icon, display: display)
        iconView.image = icon
        let attributed = NSMutableAttributedString(attributedString: HighlightedText.make(
            item.entry.info.appName, matches: item.appMatches, font: .systemFont(ofSize: 11, weight: .medium), color: .labelColor
        ))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        nameField.attributedStringValue = attributed
        nameField.toolTip = item.entry.info.title
        countBadge.text = "\(item.windowCount)"
        countBadge.isHidden = item.windowCount < 2
        countBadge.hasOutline = display.increaseContrast
        badges.badges = item.badges.prefix(1).map(\.label)
        badges.hasOutline = display.increaseContrast
    }

    override func layout() {
        super.layout()
        let side: CGFloat = 64
        let iconRect = CGRect(x: (bounds.width - side) / 2, y: 8, width: side, height: side)
        iconView.frame = iconRect
        let count = countBadge.intrinsicContentSize
        countBadge.frame = CGRect(x: iconRect.maxX - count.width + 4, y: iconRect.minY - 4, width: count.width, height: count.height)
        nameField.frame = CGRect(x: 4, y: bounds.height - 22, width: max(bounds.width - 8, 0), height: 16)
        badges.frame = CGRect(x: 4, y: iconRect.maxY - 12, width: max(bounds.width - 8, 0), height: 16)
        badges.alignsRight = false
        let barWidth = actionBar.fittingWidth
        actionBar.frame = CGRect(
            x: (bounds.width - barWidth) / 2,
            y: iconRect.midY - TileActionButton.side / 2,
            width: barWidth,
            height: TileActionButton.side
        )
    }
}
