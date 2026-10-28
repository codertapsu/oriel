import AppKit
import SharedUI

/// A row of the title list: app icon, title and app name, badges at the trailing edge, which make room for
/// the action buttons on hover.
final class TitleRowView: TileView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let badges = BadgeStack(style: .inline)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        badges.alignsRight = true
        for view in [iconView, titleField, badges] as [NSView] {
            addSubview(view)
        }
        bringActionBarToFront()
    }

    override func configure(_ item: SwitcherItem, icon: NSImage?, display: AccessibilityDisplay) {
        super.configure(item, icon: icon, display: display)
        iconView.image = icon
        let info = item.entry.info
        let text = NSMutableAttributedString(attributedString: HighlightedText.make(
            info.title, matches: item.titleMatches, font: .systemFont(ofSize: 13), color: .labelColor
        ))
        if info.title != info.appName {
            text.append(NSAttributedString(string: "  "))
            text.append(HighlightedText.make(
                info.appName,
                matches: item.appMatches,
                font: .systemFont(ofSize: 12),
                color: .secondaryLabelColor
            ))
        }
        titleField.attributedStringValue = text
        titleField.toolTip = info.title
        badges.badges = item.badges.map(\.label)
        badges.hasOutline = display.increaseContrast
    }

    override func layout() {
        super.layout()
        let iconSide: CGFloat = 18
        iconView.frame = CGRect(x: 8, y: (bounds.height - iconSide) / 2, width: iconSide, height: iconSide)
        let trailing = max(badges.fittingWidth, actionBar.isHidden ? 0 : actionBar.fittingWidth)
        let badgeWidth = min(trailing, bounds.width * 0.4)
        badges.frame = CGRect(x: bounds.width - badgeWidth - 8, y: (bounds.height - 16) / 2, width: badgeWidth, height: 16)
        let barWidth = actionBar.fittingWidth
        actionBar.frame = CGRect(
            x: bounds.width - barWidth - 8,
            y: (bounds.height - TileActionButton.side) / 2,
            width: barWidth,
            height: TileActionButton.side
        )
        let titleX = iconView.frame.maxX + 8
        titleField.frame = CGRect(x: titleX, y: (bounds.height - 18) / 2, width: max(badges.frame.minX - titleX - 8, 0), height: 18)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        badges.isHidden = !actionBar.isHidden
        needsLayout = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        badges.isHidden = false
        needsLayout = true
    }
}
