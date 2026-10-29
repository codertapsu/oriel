import CoreGraphics
import Foundation

/// The sunburst's geometry: the shown folder in the middle, its contents in the first ring, theirs in the next, each
/// with an angle proportional to its size. Segments too thin to see are merged into one "smaller items" segment per
/// folder. Angles are radians clockwise from twelve o'clock. Pure; the view draws what `segments` returns.
nonisolated enum SunburstLayout {
    struct Segment: Sendable, Equatable {
        /// The node, or `ScanNode.none` for merged smaller items.
        var node: Int32
        /// 1 for the innermost ring.
        var depth: Int
        var start: Double
        var end: Double
        /// Which of the shown folder's children it belongs to, for its color.
        var branch: Int
        var isContainer: Bool
        /// Its place among its folder's items, largest first, so neighbours get slightly different shades.
        var sibling = 0
        /// For merged smaller items: how many items, and the folder they are in.
        var mergedCount = 0
        var mergedBytes: Int64 = 0
        var parent: Int32 = ScanNode.none

        var span: Double {
            end - start
        }

        var middle: Double {
            (start + end) / 2
        }
    }

    struct Options: Sendable, Equatable {
        var rings = 5
        /// About a third of a degree: anything thinner is merged.
        var minimumAngle = 0.006
        var maximumSegments = 6000
    }

    static let fullTurn = 2 * Double.pi

    /// A folder whose ring is still to be laid out: its angular range, depth and branch.
    private struct Pending {
        var node: Int32
        var start: Double
        var end: Double
        var depth: Int
        var branch: Int
    }

    static func segments(in tree: ScanTree, root: Int32, options: Options = Options()) -> [Segment] {
        var segments: [Segment] = []
        var queue = [Pending(node: root, start: 0, end: fullTurn, depth: 0, branch: -1)]
        var head = 0
        while head < queue.count, segments.count < options.maximumSegments {
            let pending = queue[head]
            head += 1
            layOut(pending, in: tree, options: options, segments: &segments, queue: &queue)
        }
        return segments
    }

    /// The ring of `pending`'s contents, in its angular range; the folders among them are queued for the next ring.
    private static func layOut(
        _ pending: Pending,
        in tree: ScanTree,
        options: Options,
        segments: inout [Segment],
        queue: inout [Pending]
    ) {
        let total = Double(tree[pending.node].size)
        guard total > 0, pending.depth < options.rings else { return }
        let range = pending.end - pending.start
        let depth = pending.depth + 1
        var cursor = pending.start
        var mergedCount = 0
        var mergedSize = 0.0
        for (position, child) in tree.childrenBySize(of: pending.node).enumerated() {
            let size = Double(tree[child].size)
            guard size > 0 else { continue }
            let span = range * size / total
            if span < options.minimumAngle {
                mergedCount += 1
                mergedSize += size
                continue
            }
            let branch = pending.depth == 0 ? position : pending.branch
            let isContainer = tree[child].kind.isContainer
            segments.append(Segment(
                node: child, depth: depth, start: cursor, end: cursor + span, branch: branch, isContainer: isContainer, sibling: position
            ))
            if isContainer {
                queue.append(Pending(node: child, start: cursor, end: cursor + span, depth: depth, branch: branch))
            }
            cursor += span
        }
        guard mergedCount > 0 else { return }
        let end = min(pending.end, cursor + range * mergedSize / total)
        let branch = pending.depth == 0 ? -1 : pending.branch
        segments.append(Segment(
            node: ScanNode.none, depth: depth, start: cursor, end: end, branch: branch, isContainer: false,
            mergedCount: mergedCount, mergedBytes: Int64(mergedSize), parent: pending.node
        ))
    }

    /// The ring radii for a chart of `radius` with `rings` rings around a center disc.
    struct Rings: Sendable, Equatable {
        var center: CGPoint
        var centerRadius: CGFloat
        var ringWidth: CGFloat
        var rings: Int

        init(bounds: CGRect, rings: Int) {
            center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius = max(0, min(bounds.width, bounds.height) / 2 - 8)
            self.rings = rings
            // The center disc is a little wider than a ring, to hold the folder's name and size.
            centerRadius = radius * 0.24
            ringWidth = rings > 0 ? (radius - centerRadius) / CGFloat(rings) : 0
        }

        func inner(_ depth: Int) -> CGFloat {
            centerRadius + CGFloat(depth - 1) * ringWidth
        }

        func outer(_ depth: Int) -> CGFloat {
            centerRadius + CGFloat(depth) * ringWidth
        }

        /// Where `point` is: 0 for the center disc, a ring number, or nil outside the chart; and its angle. `flipped`
        /// is true for views whose y axis points down.
        func locate(_ point: CGPoint, flipped: Bool) -> (depth: Int, angle: Double)? {
            let dx = Double(point.x - center.x)
            let dy = Double(flipped ? center.y - point.y : point.y - center.y)
            let distance = CGFloat(hypot(dx, dy))
            var angle = atan2(dx, dy)
            if angle < 0 {
                angle += SunburstLayout.fullTurn
            }
            if distance <= centerRadius {
                return (0, angle)
            }
            guard ringWidth > 0 else { return nil }
            let depth = Int((distance - centerRadius) / ringWidth) + 1
            return depth <= rings ? (depth, angle) : nil
        }
    }

    /// The segment under `point`; nil over the center disc or outside the chart.
    static func segment(at point: CGPoint, in segments: [Segment], rings: Rings, flipped: Bool) -> Segment? {
        guard let location = rings.locate(point, flipped: flipped), location.depth > 0 else { return nil }
        return segments.first { $0.depth == location.depth && location.angle >= $0.start && location.angle < $0.end }
    }
}
