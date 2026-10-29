import CoreGraphics

/// The squarified treemap (Bruls, Huizing and van Wijk, 2000): rectangles with areas proportional to sizes, laid out
/// row by row along the shorter side so that they stay close to squares, which keeps small items visible and labels
/// readable. Pure; the view draws what `tiles` returns.
nonisolated enum TreemapLayout {
    struct Tile: Sendable, Equatable {
        /// The node, or `ScanNode.none` for the merged tail of items too small to draw.
        var node: Int32
        var rect: CGRect
        /// 1 for the shown folder's children, 2 for theirs, …
        var depth: Int
        /// Which of the shown folder's children it belongs to, for its color.
        var branch: Int
        var isContainer: Bool
        /// Its place among its folder's items, largest first, so neighbours get slightly different shades.
        var sibling = 0
        /// For the merged tail: how many items it stands for, and their size.
        var mergedCount = 0
        var mergedBytes: Int64 = 0
        /// The folder it is in.
        var parent: Int32 = ScanNode.none
    }

    struct Options: Sendable, Equatable {
        /// Levels opened up; with `minimumNestedSize` and `maximumTiles` this goes as deep as there is room for.
        var maxDepth = 8
        /// The strip at the top of a nested folder that carries its name.
        var headerHeight: CGFloat = 16
        var padding: CGFloat = 2
        /// Items whose area would be smaller than this (about 10 by 10 points) are merged into one tile: smaller ones
        /// end up as slivers too thin to see, point at or read.
        var minimumArea: CGFloat = 100
        /// A folder is opened up only when its tile is at least this big.
        var minimumNestedSize = CGSize(width: 48, height: 40)
        var maximumTiles = 5000
    }

    /// Rectangles for `values`, which must be sorted largest first, filling `rect` exactly.
    static func squarify(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let positive = values.map { max(0, $0) }
        let total = positive.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else {
            return values.map { _ in CGRect(x: rect.minX, y: rect.minY, width: 0, height: 0) }
        }
        let scale = Double(rect.width * rect.height) / total
        let areas = positive.map { $0 * scale }
        var result: [CGRect] = []
        result.reserveCapacity(areas.count)
        var remaining = rect
        var start = 0
        while start < areas.count {
            let side = Double(min(remaining.width, remaining.height))
            var end = start + 1
            var best = worstRatio(areas[start ..< end], side: side)
            while end < areas.count {
                let candidate = worstRatio(areas[start ... end], side: side)
                if candidate > best {
                    break
                }
                best = candidate
                end += 1
            }
            let row = areas[start ..< end]
            remaining = place(row, in: remaining, into: &result)
            start = end
        }
        return result
    }

    /// The tiles for `root`'s contents in `bounds`, nested `options.maxDepth` levels deep.
    static func tiles(in tree: ScanTree, root: Int32, bounds: CGRect, options: Options = Options()) -> [Tile] {
        var tiles: [Tile] = []
        var queue = [Pending(node: root, rect: bounds, depth: 0, branch: -1)]
        while let pending = queue.popLast(), tiles.count < options.maximumTiles {
            layOut(pending, in: tree, options: options, tiles: &tiles, queue: &queue)
        }
        return tiles
    }

    /// A folder whose contents are still to be laid out, and where.
    private struct Pending {
        var node: Int32
        var rect: CGRect
        var depth: Int
        var branch: Int
    }

    private static func layOut(_ pending: Pending, in tree: ScanTree, options: Options, tiles: inout [Tile], queue: inout [Pending]) {
        let children = tree.childrenBySize(of: pending.node).filter { tree[$0].size > 0 }
        let total = Double(tree[pending.node].size)
        guard !children.isEmpty, total > 0 else { return }
        // Keep items large enough to see; the rest become one tile.
        let area = Double(pending.rect.width * pending.rect.height)
        let cut = children.firstIndex { Double(tree[$0].size) / total * area < Double(options.minimumArea) } ?? children.count
        let shown = children[..<cut]
        let merged = children[cut...]
        var values = shown.map { Double(tree[$0].size) }
        if !merged.isEmpty {
            values.append(merged.reduce(0) { $0 + Double(tree[$1].size) })
        }
        let rects = squarify(values, in: pending.rect)
        let depth = pending.depth + 1
        for (position, child) in shown.enumerated() {
            let branch = pending.depth == 0 ? position : pending.branch
            let tile = Tile(
                node: child, rect: rects[position], depth: depth, branch: branch, isContainer: tree[child].kind.isContainer,
                sibling: position, parent: pending.node
            )
            tiles.append(tile)
            if let inner = nestedRect(for: tile, options: options) {
                queue.append(Pending(node: child, rect: inner, depth: depth, branch: branch))
            }
        }
        if !merged.isEmpty, let last = rects.last {
            let branch = pending.depth == 0 ? shown.count : pending.branch
            let bytes = merged.reduce(Int64(0)) { $0 + tree[$1].size }
            tiles.append(Tile(
                node: ScanNode.none, rect: last, depth: depth, branch: branch, isContainer: false, mergedCount: merged.count,
                mergedBytes: bytes, parent: pending.node
            ))
        }
    }

    /// Where a folder's contents go inside its tile, below the strip with its name; nil when the folder is left closed.
    private static func nestedRect(for tile: Tile, options: Options) -> CGRect? {
        guard tile.isContainer, tile.depth < options.maxDepth, tile.rect.width >= options.minimumNestedSize.width,
              tile.rect.height >= options.minimumNestedSize.height else { return nil }
        let inner = CGRect(
            x: tile.rect.minX + options.padding,
            y: tile.rect.minY + options.headerHeight,
            width: tile.rect.width - options.padding * 2,
            height: tile.rect.height - options.headerHeight - options.padding
        )
        return inner.width > 4 && inner.height > 4 ? inner : nil
    }

    /// The deepest tile under `point`, if any.
    static func tile(at point: CGPoint, in tiles: [Tile]) -> Tile? {
        tiles.filter { $0.rect.contains(point) }.max { $0.depth < $1.depth }
    }

    // MARK: Squarifying

    /// The worst aspect ratio in a row of `areas` laid along a side of length `side`; lower is squarer.
    private static func worstRatio(_ areas: ArraySlice<Double>, side: Double) -> Double {
        let sum = areas.reduce(0, +)
        guard sum > 0, side > 0, let largest = areas.max(), let smallest = areas.min(), smallest > 0 else { return .infinity }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * largest / sumSquared, sumSquared / (sideSquared * smallest))
    }

    /// Lays `row` along the shorter side of `rect`, appends the rectangles and returns what is left of `rect`.
    private static func place(_ row: ArraySlice<Double>, in rect: CGRect, into result: inout [CGRect]) -> CGRect {
        let sum = row.reduce(0, +)
        if rect.width >= rect.height {
            // A column on the left.
            let width = rect.height > 0 ? CGFloat(sum) / rect.height : 0
            var y = rect.minY
            for area in row {
                let height = width > 0 ? CGFloat(area) / width : 0
                result.append(CGRect(x: rect.minX, y: y, width: width, height: height))
                y += height
            }
            return CGRect(x: rect.minX + width, y: rect.minY, width: max(0, rect.width - width), height: rect.height)
        }
        // A row along the top (the low-y side).
        let height = rect.width > 0 ? CGFloat(sum) / rect.width : 0
        var x = rect.minX
        for area in row {
            let width = height > 0 ? CGFloat(area) / height : 0
            result.append(CGRect(x: x, y: rect.minY, width: width, height: height))
            x += width
        }
        return CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: max(0, rect.height - height))
    }
}
