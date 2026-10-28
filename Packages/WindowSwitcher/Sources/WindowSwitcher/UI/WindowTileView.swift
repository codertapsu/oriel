import AppKit
import SharedUI

/// A thumbnail tile: the window's capture (or its app's icon until one arrives, and always without Screen
/// Recording), badges on top, app icon and title below.
final class WindowTileView: TileView {
    private let thumbnail = ThumbnailView()
    private let placeholder = NSImageView()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let badges = BadgeStack(style: .overlay)
    private var windowID: UInt32?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        placeholder.imageScaling = .scaleProportionallyUpOrDown
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        for view in [thumbnail, placeholder, iconView, titleField, badges] as [NSView] {
            addSubview(view)
        }
        bringActionBarToFront()
    }

    override func configure(_ item: SwitcherItem, icon: NSImage?, display: AccessibilityDisplay) {
        super.configure(item, icon: icon, display: display)
        if windowID != item.id {
            setThumbnail(nil)
            windowID = item.id
        }
        placeholder.image = icon
        iconView.image = icon
        let info = item.entry.info
        titleField.attributedStringValue = HighlightedText.make(
            info.title, matches: item.titleMatches, font: .systemFont(ofSize: 12, weight: .medium), color: .labelColor
        )
        titleField.toolTip = info.title
        badges.badges = item.badges.map(\.label)
        badges.hasOutline = display.increaseContrast
    }

    override func setThumbnail(_ image: CGImage?) {
        thumbnail.image = image
        placeholder.isHidden = image != nil
    }

    override func layout() {
        super.layout()
        let caption = LayoutMetrics.thumbnails(maximumTileWidth: 0).captionHeight
        let imageRect = CGRect(x: 6, y: 6, width: max(bounds.width - 12, 0), height: max(bounds.height - caption - 6, 0))
        thumbnail.frame = imageRect
        let side = min(64, imageRect.height * 0.6, imageRect.width * 0.6)
        placeholder.frame = CGRect(x: imageRect.midX - side / 2, y: imageRect.midY - side / 2, width: side, height: side)
        iconView.frame = CGRect(x: 8, y: bounds.height - caption + 5, width: 16, height: 16)
        titleField.frame = CGRect(x: 30, y: bounds.height - caption + 4, width: max(bounds.width - 38, 0), height: 18)
        let barWidth = actionBar.fittingWidth
        actionBar.frame = CGRect(x: imageRect.maxX - barWidth - 4, y: imageRect.minY + 4, width: barWidth, height: TileActionButton.side)
        badges.frame = CGRect(x: imageRect.minX + 4, y: imageRect.maxY - 20, width: max(imageRect.width - 8, 0), height: 16)
    }
}
