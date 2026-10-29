import CoreGraphics

/// Automatic sizing (PLAN §10.3), pure and table-tested. For n tiles in a panel of at most `maximumSize`,
/// choose rows r and tile width w that maximize w subject to cols = ceil(n / r), cols·w + gaps ≤ maxW,
/// r·(w / aspect + caption) + gaps ≤ maxH and w ∈ [minTile, maxTile]; ties go to fewer rows. When not even
/// minTile fits, tiles stay at minTile and the rows scroll. A grouped grid counts its header band in every row, a
/// grouped list its header rows, and the key hints come off the height first.
nonisolated enum LayoutCalculator {
    /// The default maximum panel: 80 % of the visible frame's width, 60 % of its height.
    static let maximumFraction = CGSize(width: 0.8, height: 0.6)

    static func maximumPanelSize(forVisibleFrame frame: CGSize) -> CGSize {
        CGSize(width: (frame.width * maximumFraction.width).rounded(.down), height: (frame.height * maximumFraction.height).rounded(.down))
    }

    /// - Parameters:
    ///   - groupStarts: the first item of each group when the shortcut groups by app, nil when it does not. The
    ///     app-icons style, one tile per app already, never shows group headers.
    ///   - showsHints: whether the key hints go under the tiles; never under an empty panel.
    static func layout(
        count: Int,
        style: DisplayStyle,
        metrics: LayoutMetrics,
        maximumSize: CGSize,
        showsSearchBar: Bool,
        groupStarts: [Int]? = nil,
        showsHints: Bool = false
    ) -> SwitcherLayout {
        let search = showsSearchBar ? metrics.searchBarHeight : 0
        guard count > 0 else {
            return SwitcherLayout(
                count: 0, columns: 1, rows: 0, visibleRows: 0, tileSize: .zero, spacing: metrics.spacing,
                padding: metrics.padding, searchBarHeight: search,
                panelSize: CGSize(width: min(metrics.emptySize.width, maximumSize.width), height: metrics.emptySize.height + search)
            )
        }
        let chrome = Chrome(search: search, footer: showsHints ? metrics.footerHeight : 0, headers: headers(style, groupStarts, metrics))
        return style == .titles
            ? list(count: count, metrics: metrics, maximumSize: maximumSize, chrome: chrome)
            : grid(count: count, metrics: metrics, maximumSize: maximumSize, chrome: chrome)
    }

    /// What surrounds the tiles: the search bar, the key hints and the group headers.
    private struct Chrome {
        var search: CGFloat
        var footer: CGFloat
        var headers: GroupHeaders

        /// The header band every grid row carries.
        var band: CGFloat {
            if case let .aboveRows(height) = headers {
                return height
            }
            return 0
        }
    }

    private static func headers(_ style: DisplayStyle, _ starts: [Int]?, _ metrics: LayoutMetrics) -> GroupHeaders {
        guard let starts, style != .appIcons else { return .none }
        return style == .titles ? .aboveGroups(starts: starts, height: metrics.groupHeaderHeight) :
            .aboveRows(height: metrics.groupHeaderHeight)
    }

    private static func grid(count: Int, metrics: LayoutMetrics, maximumSize: CGSize, chrome: Chrome) -> SwitcherLayout {
        let availableWidth = maximumSize.width - 2 * metrics.padding
        let availableHeight = maximumSize.height - 2 * metrics.padding - chrome.search - chrome.footer
        var best: (rows: Int, columns: Int, width: CGFloat)?
        for rows in 1 ... count {
            let columns = (count + rows - 1) / rows
            // More rows than the items need would leave the last one empty.
            if rows > 1, (rows - 1) * columns >= count {
                continue
            }
            let widthLimit = (availableWidth - CGFloat(columns - 1) * metrics.spacing) / CGFloat(columns)
            let rowHeight = (availableHeight - CGFloat(rows - 1) * metrics.spacing) / CGFloat(rows) - chrome.band
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
                chrome: chrome
            )
        }
        let width = metrics.minimumTileWidth
        let rowHeight = metrics.tileHeight(forWidth: width) + chrome.band
        let columns = max(1, min(count, Int((availableWidth + metrics.spacing) / (width + metrics.spacing))))
        let rows = (count + columns - 1) / columns
        let visibleRows = max(1, min(rows, Int((availableHeight + metrics.spacing) / (rowHeight + metrics.spacing))))
        return make(count: count, columns: columns, rows: rows, visibleRows: visibleRows, width: width, metrics: metrics, chrome: chrome)
    }

    private static func list(count: Int, metrics: LayoutMetrics, maximumSize: CGSize, chrome: Chrome) -> SwitcherLayout {
        let width = max(min(metrics.maximumTileWidth, maximumSize.width - 2 * metrics.padding), 1)
        let availableHeight = maximumSize.height - 2 * metrics.padding - chrome.search - chrome.footer
        let rowHeight = metrics.captionHeight
        let tile = CGSize(width: width.rounded(.down), height: rowHeight)
        var layout = SwitcherLayout(
            count: count, columns: 1, rows: count, visibleRows: count, tileSize: tile, spacing: metrics.spacing,
            padding: metrics.padding, searchBarHeight: chrome.search, panelSize: .zero, headers: chrome.headers,
            footerHeight: chrome.footer
        )
        // As many rows as fit without headers, then fewer while the headers among them push past the height.
        var visibleRows = max(1, min(count, Int((availableHeight + metrics.spacing) / (rowHeight + metrics.spacing))))
        while visibleRows > 1, layout.height(ofRows: visibleRows) - 2 * metrics.padding > availableHeight {
            visibleRows -= 1
        }
        layout.visibleRows = visibleRows
        layout.panelSize = CGSize(
            width: tile.width + 2 * metrics.padding,
            height: layout.height(ofRows: visibleRows) + chrome.search + chrome.footer
        )
        return layout
    }

    private static func make(
        count: Int,
        columns: Int,
        rows: Int,
        visibleRows: Int,
        width: CGFloat,
        metrics: LayoutMetrics,
        chrome: Chrome
    ) -> SwitcherLayout {
        let tile = CGSize(width: width, height: metrics.tileHeight(forWidth: width))
        var layout = SwitcherLayout(
            count: count, columns: columns, rows: rows, visibleRows: visibleRows, tileSize: tile, spacing: metrics.spacing,
            padding: metrics.padding, searchBarHeight: chrome.search, panelSize: .zero, headers: chrome.headers,
            footerHeight: chrome.footer
        )
        let contentWidth = 2 * metrics.padding + CGFloat(columns) * width + CGFloat(columns - 1) * metrics.spacing
        let panelWidth = max(contentWidth, metrics.emptySize.width)
        layout.panelSize = CGSize(width: panelWidth, height: layout.height(ofRows: visibleRows) + chrome.search + chrome.footer)
        layout.leadingInset = ((panelWidth - contentWidth) / 2).rounded(.down)
        return layout
    }
}
