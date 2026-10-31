import AppKit
import SharedUI

/// The Dock preview (PLAN §7.1.12): a non-activating glass panel next to the hovered icon, with the app's icon and name
/// above its windows as the switcher's thumbnail tiles, most recently used first. Hovering a tile highlights it and shows
/// its buttons (close, minimize, full screen); a click switches to the window. The panel says when the pointer enters and
/// leaves it.
final class DockPreviewPanel {
    var onClick: ((WindowEntry) -> Void)?
    var onAction: ((WindowEntry, TileAction) -> Void)?
    var onPointerInside: ((Bool) -> Void)?

    private let panel = FloatingPanel(level: .popUpMenu)
    private let background = Material.make(cornerRadius: 16)
    private let content = DockPreviewContentView()
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private var tiles: [WindowTileView] = []
    /// The window whose tile the pointer is on, which stays highlighted when the tiles are shown again.
    private var highlighted: UInt32?
    private(set) var isVisible = false

    init() {
        panel.contentView = background
        content.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
        ])
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.lineBreakMode = .byTruncatingTail
        content.addSubview(iconView)
        content.addSubview(titleField)
        content.onPointerInside = { [weak self] inside in
            if !inside {
                self?.highlight(nil)
            }
            self?.onPointerInside?(inside)
        }
    }

    /// Where it is, Cocoa coordinates.
    var frame: CGRect {
        panel.frame
    }

    /// The windows on screen now, for memory-pressure purges.
    var windowIDs: Set<UInt32> {
        Set(tiles.compactMap(\.item?.id))
    }

    /// Shows the first `layout.count` of `items` at `frame` (Cocoa coordinates).
    func show(_ items: [SwitcherItem], title: String, icon: NSImage?, layout: DockPreviewLayout, frame: CGRect) {
        let display = AccessibilityDisplay.current
        let shown = Array(items.prefix(layout.count))
        while tiles.count < shown.count {
            let tile = WindowTileView()
            content.addSubview(tile)
            tiles.append(tile)
        }
        while tiles.count > shown.count {
            tiles.removeLast().removeFromSuperview()
        }
        for (index, item) in shown.enumerated() {
            let tile = tiles[index]
            tile.frame = layout.frame(ofTile: index)
            tile.configure(item, icon: icon, display: display)
            tile.isSelected = item.id == highlighted
            tile.onHover = { [weak self] in self?.highlight(item.id) }
            tile.onClick = { [weak self] in self?.onClick?(item.entry) }
            tile.onAction = { [weak self] action in self?.onAction?(item.entry, action) }
        }
        let padding = DockPreviewLayout.padding
        iconView.image = icon
        iconView.frame = CGRect(x: padding + 2, y: padding, width: 18, height: 18)
        titleField.stringValue = shown.count < items.count ? "\(title) — \(shown.count) of \(items.count) windows" : title
        titleField.frame = CGRect(x: padding + 26, y: padding, width: max(frame.width - 2 * padding - 28, 0), height: 18)
        panel.setAccessibilityLabel("Windows of \(title)")
        panel.setFrame(frame, display: true)
        if !isVisible {
            panel.orderFrontRegardless()
            isVisible = true
        }
    }

    func setThumbnail(_ image: CGImage, for windowID: UInt32) {
        for tile in tiles where tile.item?.id == windowID {
            tile.setThumbnail(image)
        }
    }

    func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        highlight(nil)
    }

    private func highlight(_ windowID: UInt32?) {
        highlighted = windowID
        for tile in tiles {
            tile.isSelected = windowID != nil && tile.item?.id == windowID
        }
    }
}
