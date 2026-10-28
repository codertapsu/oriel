import CoreGraphics

/// Where everything goes in the switcher panel. Tile frames are in content coordinates: origin at the top
/// left of the scrolled content, y going down.
nonisolated struct SwitcherLayout: Sendable, Equatable {
    var count: Int
    var columns: Int
    var rows: Int
    /// Rows that fit without scrolling.
    var visibleRows: Int
    var tileSize: CGSize
    var spacing: CGFloat
    var padding: CGFloat
    /// Zero unless a search is shown.
    var searchBarHeight: CGFloat
    var panelSize: CGSize
    /// Centers the tiles when the panel is wider than they are (it never gets narrower than the empty panel).
    var leadingInset: CGFloat = 0

    var isScrolling: Bool {
        rows > visibleRows
    }

    /// All rows, with padding.
    var contentSize: CGSize {
        CGSize(width: panelSize.width, height: height(ofRows: rows))
    }

    /// The scrolled area below the search bar.
    var viewportSize: CGSize {
        CGSize(width: panelSize.width, height: panelSize.height - searchBarHeight)
    }

    func frame(ofItem index: Int) -> CGRect {
        let row = index / max(columns, 1)
        let column = index % max(columns, 1)
        return CGRect(
            x: leadingInset + padding + CGFloat(column) * (tileSize.width + spacing),
            y: padding + CGFloat(row) * (tileSize.height + spacing),
            width: tileSize.width,
            height: tileSize.height
        )
    }

    func height(ofRows rows: Int) -> CGFloat {
        guard rows > 0 else { return 2 * padding }
        return 2 * padding + CGFloat(rows) * tileSize.height + CGFloat(rows - 1) * spacing
    }
}
