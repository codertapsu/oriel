import CoreGraphics

/// Which display a window is on, and which display comes next, however the displays are arranged. Pure.
nonisolated enum DisplayArrangement {
    /// The display showing most of `frame`; for a window on none of them, the one whose visible frame is nearest.
    static func index(of frame: CGRect, in displays: [DisplayGeometry]) -> Int? {
        guard !displays.isEmpty else { return nil }
        var best: (index: Int, area: CGFloat)?
        for (index, display) in displays.enumerated() {
            let overlap = display.frame.intersection(frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > 0, area > best?.area ?? 0 {
                best = (index, area)
            }
        }
        if let best {
            return best.index
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return displays.indices.min { distance(from: center, to: displays[$0].visibleFrame) < distance(
            from: center,
            to: displays[$1].visibleFrame
        ) }
    }

    /// The display after `index` (or before it), in reading order: left to right, then top to bottom. It wraps around,
    /// so every display is a few presses away.
    static func neighbour(of index: Int, forward: Bool, in displays: [DisplayGeometry]) -> Int {
        guard displays.count > 1, displays.indices.contains(index) else { return index }
        let order = displays.indices.sorted { lhs, rhs in
            let left = displays[lhs].frame
            let right = displays[rhs].frame
            return left.minX == right.minX ? left.minY < right.minY : left.minX < right.minX
        }
        guard let position = order.firstIndex(of: index) else { return index }
        let next = (position + (forward ? 1 : -1) + order.count) % order.count
        return order[next]
    }

    /// How far `point` is from `rect`; zero inside it.
    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
