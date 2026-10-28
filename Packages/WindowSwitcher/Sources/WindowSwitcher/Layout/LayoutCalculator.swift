import CoreGraphics

/// Automatic sizing (PLAN §10.3), pure and table-tested. For n tiles in a panel of at most `maximumSize`,
/// choose rows r and tile width w that maximize w subject to cols = ceil(n / r), cols·w + gaps ≤ maxW,
/// r·(w / aspect + caption) + gaps ≤ maxH and w ∈ [minTile, maxTile]; ties go to fewer rows. When not even
/// minTile fits, tiles stay at minTile and the rows scroll.
nonisolated enum LayoutCalculator {
    /// The default maximum panel: 80 % of the visible frame's width, 60 % of its height.
    static let maximumFraction = CGSize(width: 0.8, height: 0.6)

    static func maximumPanelSize(forVisibleFrame frame: CGSize) -> CGSize {
        CGSize(width: (frame.width * maximumFraction.width).rounded(.down), height: (frame.height * maximumFraction.height).rounded(.down))
    }

    static func layout(
        count: Int,
        style: DisplayStyle,
        metrics: LayoutMetrics,
        maximumSize: CGSize,
        showsSearchBar: Bool
    ) -> SwitcherLayout {
        let search = showsSearchBar ? metrics.searchBarHeight : 0
        guard count > 0 else {
            return SwitcherLayout(
                count: 0, columns: 1, rows: 0, visibleRows: 0, tileSize: .zero, spacing: metrics.spacing,
                padding: metrics.padding, searchBarHeight: search,
                panelSize: CGSize(width: min(metrics.emptySize.width, maximumSize.width), height: metrics.emptySize.height + search)
            )
        }
        return style == .titles
            ? list(count: count, metrics: metrics, maximumSize: maximumSize, search: search)
            : grid(count: count, metrics: metrics, maximumSize: maximumSize, search: search)
    }

    private static func grid(count: Int, metrics: LayoutMetrics, maximumSize: CGSize, search: CGFloat) -> SwitcherLayout {
        let availableWidth = maximumSize.width - 2 * metrics.padding
        let availableHeight = maximumSize.height - 2 * metrics.padding - search
        var best: (rows: Int, columns: Int, width: CGFloat)?
        for rows in 1 ... count {
            let columns = (count + rows - 1) / rows
            // More rows than the items need would leave the last one empty.
            if rows > 1, (rows - 1) * columns >= count {
                continue
            }
            let widthLimit = (availableWidth - CGFloat(columns - 1) * metrics.spacing) / CGFloat(columns)
            let rowHeight = (availableHeight - CGFloat(rows - 1) * metrics.spacing) / CGFloat(rows)
            let heightLimit = (rowHeight - metrics.captionHeight) * metrics.imageAspectRatio
            let width = min(metrics.maximumTileWidth, widthLimit, heightLimit).rounded(.down)
            if width >= metrics.minimumTileWidth, width > best?.width ?? 0 {
                best = (rows, columns, width)
            }
        }
        if let best {
            return make(
                count: count,
                columns: best.columns,
                rows: best.rows,
                visibleRows: best.rows,
                width: best.width,
                metrics: metrics,
                search: search
            )
        }
        let width = metrics.minimumTileWidth
        let tileHeight = metrics.tileHeight(forWidth: width)
        let columns = max(1, min(count, Int((availableWidth + metrics.spacing) / (width + metrics.spacing))))
        let rows = (count + columns - 1) / columns
        let visibleRows = max(1, min(rows, Int((availableHeight + metrics.spacing) / (tileHeight + metrics.spacing))))
        return make(count: count, columns: columns, rows: rows, visibleRows: visibleRows, width: width, metrics: metrics, search: search)
    }

    private static func list(count: Int, metrics: LayoutMetrics, maximumSize: CGSize, search: CGFloat) -> SwitcherLayout {
        let width = max(min(metrics.maximumTileWidth, maximumSize.width - 2 * metrics.padding), 1)
        let availableHeight = maximumSize.height - 2 * metrics.padding - search
        let rowHeight = metrics.captionHeight
        let visibleRows = max(1, min(count, Int((availableHeight + metrics.spacing) / (rowHeight + metrics.spacing))))
        let tile = CGSize(width: width.rounded(.down), height: rowHeight)
        var layout = SwitcherLayout(
            count: count, columns: 1, rows: count, visibleRows: visibleRows, tileSize: tile, spacing: metrics.spacing,
            padding: metrics.padding, searchBarHeight: search, panelSize: .zero
        )
        layout.panelSize = CGSize(width: tile.width + 2 * metrics.padding, height: layout.height(ofRows: visibleRows) + search)
        return layout
    }

    private static func make(
        count: Int,
        columns: Int,
        rows: Int,
        visibleRows: Int,
        width: CGFloat,
        metrics: LayoutMetrics,
        search: CGFloat
    ) -> SwitcherLayout {
        let tile = CGSize(width: width, height: metrics.tileHeight(forWidth: width))
        var layout = SwitcherLayout(
            count: count, columns: columns, rows: rows, visibleRows: visibleRows, tileSize: tile, spacing: metrics.spacing,
            padding: metrics.padding, searchBarHeight: search, panelSize: .zero
        )
        let contentWidth = 2 * metrics.padding + CGFloat(columns) * width + CGFloat(columns - 1) * metrics.spacing
        let panelWidth = max(contentWidth, metrics.emptySize.width)
        layout.panelSize = CGSize(width: panelWidth, height: layout.height(ofRows: visibleRows) + search)
        layout.leadingInset = ((panelWidth - contentWidth) / 2).rounded(.down)
        return layout
    }
}
