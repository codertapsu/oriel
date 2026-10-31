import CoreGraphics

/// The Dock preview's grid and place (PLAN §7.1.12): the app's window tiles in a row above a Dock at the bottom and in a
/// column beside one at the side, wrapping into more rows or columns when they do not fit, with smaller tiles before
/// fewer; next to the icon and inside the screen's visible frame, which leaves out the Dock and the menu bar. Pure.
nonisolated struct DockPreviewLayout: Sendable, Equatable {
    static let padding: CGFloat = 12
    static let spacing: CGFloat = 10
    /// The app's icon and name above the tiles.
    static let headerHeight: CGFloat = 26
    /// Between the icon and the panel, and the panel and the screen's edges.
    static let gap: CGFloat = 6
    static let margin: CGFloat = 8
    static let minimumTileWidth: CGFloat = 120
    static let maximumTileWidth: CGFloat = 260

    var tileSize: CGSize
    var columns: Int
    var rows: Int
    /// How many tiles show: the most recently used windows, when there are more than the screen holds.
    var count: Int
    var edge: DockLayout.Edge

    var panelSize: CGSize {
        CGSize(
            width: 2 * Self.padding + CGFloat(columns) * tileSize.width + CGFloat(max(columns - 1, 0)) * Self.spacing,
            height: 2 * Self.padding + Self.headerHeight + CGFloat(rows) * tileSize.height + CGFloat(max(rows - 1, 0)) * Self.spacing
        )
    }

    /// Tile `index`'s frame in the panel (y down from the top): along the row for a bottom Dock, down the column for a
    /// side one.
    func frame(ofTile index: Int) -> CGRect {
        let (column, row) = edge == .bottom ? (index % columns, index / columns) : (index / rows, index % rows)
        return CGRect(
            x: Self.padding + CGFloat(column) * (tileSize.width + Self.spacing),
            y: Self.padding + Self.headerHeight + CGFloat(row) * (tileSize.height + Self.spacing),
            width: tileSize.width,
            height: tileSize.height
        )
    }

    /// - Parameters:
    ///   - count: the app's windows.
    ///   - tileWidth: the preferred width, the switcher's thumbnail size.
    ///   - available: the visible frame's size, less the margins.
    static func make(
        count: Int,
        tileWidth: CGFloat,
        edge: DockLayout.Edge,
        available: CGSize,
        metrics: LayoutMetrics
    ) -> DockPreviewLayout {
        var width = min(max(tileWidth, minimumTileWidth), maximumTileWidth)
        while true {
            let size = CGSize(width: width, height: metrics.tileHeight(forWidth: width))
            let fitColumns = max(1, Int((available.width - 2 * padding + spacing) / (size.width + spacing)))
            let fitRows = max(1, Int((available.height - 2 * padding - headerHeight + spacing) / (size.height + spacing)))
            let (columns, rows) = grid(count: count, edge: edge, fitColumns: fitColumns, fitRows: fitRows)
            if (columns <= fitColumns && rows <= fitRows) || width <= minimumTileWidth {
                let shown = min(count, min(columns, fitColumns) * min(rows, fitRows))
                let (finalColumns, finalRows) = grid(count: shown, edge: edge, fitColumns: fitColumns, fitRows: fitRows)
                return DockPreviewLayout(tileSize: size, columns: finalColumns, rows: finalRows, count: shown, edge: edge)
            }
            width = max(minimumTileWidth, (width * 0.85).rounded(.down))
        }
    }

    /// A row (at the bottom) or a column (at the side) as long as fits, then as many more as needed.
    private static func grid(count: Int, edge: DockLayout.Edge, fitColumns: Int, fitRows: Int) -> (columns: Int, rows: Int) {
        let count = max(count, 1)
        if edge == .bottom {
            let columns = min(count, fitColumns)
            return (columns, (count + columns - 1) / columns)
        }
        let rows = min(count, fitRows)
        return ((count + rows - 1) / rows, rows)
    }

    /// Whether the pointer still keeps the preview: on the hovered icon as the hover read found it (grown, in a magnified
    /// Dock), in the panel or between the two, or near the Dock as last read (`dock`), when that read still holds. All
    /// Cocoa coordinates.
    static func keepsPreview(pointer: CGPoint, icon: CGRect, panel: CGRect, dock: CGRect?) -> Bool {
        if let dock, dock.insetBy(dx: -gap, dy: -gap).contains(pointer) {
            return true
        }
        return icon.union(panel).contains(pointer)
    }

    /// The panel's frame (Cocoa coordinates) next to the icon's (Cocoa), inside `visibleFrame`.
    static func panelFrame(size: CGSize, icon: CGRect, edge: DockLayout.Edge, visibleFrame: CGRect) -> CGRect {
        var origin = switch edge {
        case .bottom: CGPoint(x: icon.midX - size.width / 2, y: icon.maxY + gap)
        case .left: CGPoint(x: icon.maxX + gap, y: icon.midY - size.height / 2)
        case .right: CGPoint(x: icon.minX - gap - size.width, y: icon.midY - size.height / 2)
        }
        origin.x = max(min(origin.x, visibleFrame.maxX - margin - size.width), visibleFrame.minX + margin)
        origin.y = max(min(origin.y, visibleFrame.maxY - margin - size.height), visibleFrame.minY + margin)
        return CGRect(x: origin.x.rounded(), y: origin.y.rounded(), width: size.width, height: size.height)
    }
}
