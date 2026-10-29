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
    /// The apps' names when the shortcut groups by app.
    var headers: GroupHeaders = .none
    /// The key hints under the tiles; zero when they are hidden.
    var footerHeight: CGFloat = 0

    var isScrolling: Bool {
        rows > visibleRows
    }

    /// All rows, with padding.
    var contentSize: CGSize {
        CGSize(width: panelSize.width, height: height(ofRows: rows))
    }

    /// The scrolled area between the search bar and the key hints.
    var viewportSize: CGSize {
        CGSize(width: panelSize.width, height: panelSize.height - searchBarHeight - footerHeight)
    }

    func frame(ofItem index: Int) -> CGRect {
        let row = index / max(columns, 1)
        let column = index % max(columns, 1)
        return CGRect(
            x: leadingInset + padding + CGFloat(column) * (tileSize.width + spacing),
            y: padding + CGFloat(row) * (tileSize.height + spacing) + headerHeight(before: index),
            width: tileSize.width,
            height: tileSize.height
        )
    }

    /// The first `rows` rows, with padding and their group headers.
    func height(ofRows rows: Int) -> CGFloat {
        guard rows > 0 else { return 2 * padding }
        let headers = switch headers {
        case .none: CGFloat(0)
        case let .aboveRows(height): CGFloat(rows) * height
        case let .aboveGroups(starts, height): CGFloat(starts.count { $0 < rows * max(columns, 1) }) * height
        }
        return 2 * padding + CGFloat(rows) * tileSize.height + CGFloat(rows - 1) * spacing + headers
    }

    /// What scrolling reveals when item `index` is selected: the item, its group's label above it, and the padding.
    func revealRect(ofItem index: Int) -> CGRect {
        let frame = frame(ofItem: index)
        let header = switch headers {
        case .none: CGFloat(0)
        case let .aboveRows(height), let .aboveGroups(_, height): height
        }
        return CGRect(x: frame.minX, y: frame.minY - header - padding, width: frame.width, height: frame.height + header + 2 * padding)
    }

    /// Where the group labels go, for groups given as ranges of item indexes: in a grid, one over each group's tiles
    /// in every row it reaches; in a list, one above each group.
    func headerPlacements(for groups: [Range<Int>]) -> [GroupHeaderPlacement] {
        switch headers {
        case .none:
            return []
        case let .aboveGroups(_, height):
            return groups.enumerated().compactMap { index, group in
                guard !group.isEmpty, group.lowerBound < count else { return nil }
                let first = frame(ofItem: group.lowerBound)
                return GroupHeaderPlacement(
                    group: index,
                    frame: CGRect(x: first.minX, y: first.minY - height, width: first.width, height: height)
                )
            }
        case let .aboveRows(height):
            let columns = max(columns, 1)
            var placements: [GroupHeaderPlacement] = []
            for (index, group) in groups.enumerated() where !group.isEmpty && group.lowerBound < count {
                let last = min(group.upperBound, count) - 1
                for row in (group.lowerBound / columns) ... (last / columns) {
                    let start = frame(ofItem: max(group.lowerBound, row * columns))
                    let end = frame(ofItem: min(last, (row + 1) * columns - 1))
                    let frame = CGRect(x: start.minX, y: start.minY - height, width: end.maxX - start.minX, height: height)
                    placements.append(GroupHeaderPlacement(group: index, frame: frame))
                }
            }
            return placements
        }
    }

    /// The group headers above item `index` and every item before it.
    private func headerHeight(before index: Int) -> CGFloat {
        switch headers {
        case .none:
            0
        case let .aboveRows(height):
            CGFloat(index / max(columns, 1) + 1) * height
        case let .aboveGroups(starts, height):
            CGFloat(starts.count { $0 <= index }) * height
        }
    }
}
