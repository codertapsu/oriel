import AppKit
import SharedUI

/// The switcher panel (PLAN §7.1.10): a `FloatingPanel` at `.popUpMenu`, non-activating, on the screen under
/// the pointer, with glass (or the opaque accessibility fill) from `Material` and tiles placed by
/// `LayoutCalculator`. It renders a `SwitcherSessionModel` and reports hover, clicks and hover actions.
/// Tile views are reused between sessions of the same style, and group headers between renders.
final class SwitcherPanelController {
    var onHover: ((Int) -> Void)?
    var onClick: ((Int) -> Void)?
    var onAction: ((Int, TileAction) -> Void)?

    private let panel = FloatingPanel(level: .popUpMenu)
    private let background = Material.make(cornerRadius: 20)
    private let content = SwitcherContentView()
    private var tiles: [TileView] = []
    private var headers: [GroupHeaderView] = []
    private var tileStyle: DisplayStyle?
    private var renderedToken: Int?
    private var renderedVersion: Int?
    private var renderedSelection: Int?
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
        panel.setAccessibilityLabel("Window Switcher")
    }

    /// The tiles currently shown, in item order.
    var tileViews: [TileView] {
        tiles
    }

    func render(_ model: SwitcherSessionModel, icons: AppIconCache) {
        let isNewSession = renderedToken != model.token
        if isNewSession || renderedVersion != model.version {
            reload(model, icons: icons, display: AccessibilityDisplay.current)
        }
        if renderedSelection != model.selection {
            select(model.selection, in: model.layout)
        }
        if !isVisible {
            panel.animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .utilityWindow
            panel.orderFrontRegardless()
            isVisible = true
        }
        renderedToken = model.token
    }

    func setThumbnail(_ image: CGImage, for windowID: UInt32) {
        for tile in tiles where tile.item?.id == windowID {
            tile.setThumbnail(image)
        }
    }

    func hide() {
        if isVisible {
            panel.orderOut(nil)
            isVisible = false
        }
        renderedToken = nil
        renderedVersion = nil
        renderedSelection = nil
    }

    /// The image area of a thumbnail tile, in points.
    static func imageSize(of layout: SwitcherLayout, style: DisplayStyle) -> CGSize {
        let caption = LayoutMetrics.forStyle(style, thumbnailWidth: layout.tileSize.width).captionHeight
        return CGSize(width: max(layout.tileSize.width - 12, 1), height: max(layout.tileSize.height - caption - 6, 1))
    }

    private func reload(_ model: SwitcherSessionModel, icons: AppIconCache, display: AccessibilityDisplay) {
        if tileStyle != model.style {
            tiles.forEach { $0.removeFromSuperview() }
            tiles.removeAll()
            tileStyle = model.style
        }
        while tiles.count < model.items.count {
            let tile = Self.makeTile(for: model.style)
            content.grid.addSubview(tile)
            tiles.append(tile)
        }
        while tiles.count > model.items.count {
            tiles.removeLast().removeFromSuperview()
        }
        for (index, item) in model.items.enumerated() {
            let tile = tiles[index]
            tile.frame = model.layout.frame(ofItem: index)
            tile.configure(item, icon: icons.icon(for: item.entry.info.pid, bundleID: item.entry.info.bundleID), display: display)
            tile.isSelected = false
            tile.onHover = { [weak self] in self?.onHover?(index) }
            tile.onClick = { [weak self] in self?.onClick?(index) }
            tile.onAction = { [weak self] action in self?.onAction?(index, action) }
        }
        reloadHeaders(model, icons: icons)
        content.layoutModel = model.layout
        content.searchBar.update(query: model.query, resultCount: model.items.count)
        content.hints.update(model.hints)
        content.showEmpty(query: model.query)
        place(model)
        content.layoutSubtreeIfNeeded()
        renderedVersion = model.version
        renderedSelection = nil
    }

    /// One label per group, or per group and row in a grid; none unless the shortcut groups by app.
    private func reloadHeaders(_ model: SwitcherSessionModel, icons: AppIconCache) {
        let placements = model.layout.headerPlacements(for: model.groups.map(\.items))
        while headers.count < placements.count {
            let header = GroupHeaderView()
            content.grid.addSubview(header)
            headers.append(header)
        }
        while headers.count > placements.count {
            headers.removeLast().removeFromSuperview()
        }
        for (header, placement) in zip(headers, placements) {
            let group = model.groups[placement.group]
            header.frame = placement.frame
            header.configure(name: group.appName, icon: icons.icon(for: group.pid, bundleID: group.bundleID))
        }
    }

    private func select(_ index: Int, in layout: SwitcherLayout) {
        for (position, tile) in tiles.enumerated() {
            tile.isSelected = position == index
        }
        if tiles.indices.contains(index) {
            content.grid.scrollToVisible(layout.revealRect(ofItem: index))
            NSAccessibility.post(element: tiles[index], notification: .focusedUIElementChanged)
        }
        renderedSelection = index
    }

    /// Centered on the visible frame of the screen under the pointer.
    private func place(_ model: SwitcherSessionModel) {
        let size = model.layout.panelSize
        let visible = model.screen.visibleFrame
        let frame = CGRect(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: isVisible)
    }

    private static func makeTile(for style: DisplayStyle) -> TileView {
        switch style {
        case .thumbnails: WindowTileView()
        case .appIcons: AppIconTileView()
        case .titles: TitleRowView()
        }
    }
}
