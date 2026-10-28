import CoreGraphics

/// Window and display edges the area selection snaps to while it is drawn, resized or moved (PLAN §7.2, item 4).
nonisolated struct EdgeSnapping: Sendable, Equatable {
    /// x of vertical edges, global points.
    var xs: [CGFloat]
    /// y of horizontal edges, global points.
    var ys: [CGFloat]
    /// How close (in points) an edge has to be to pull the selection onto it.
    var threshold: CGFloat

    init(xs: [CGFloat] = [], ys: [CGFloat] = [], threshold: CGFloat = 8) {
        self.xs = xs
        self.ys = ys
        self.threshold = threshold
    }

    /// The four edges of each frame.
    init(frames: [CGRect], threshold: CGFloat = 8) {
        self.init(
            xs: frames.flatMap { [$0.minX, $0.maxX] },
            ys: frames.flatMap { [$0.minY, $0.maxY] },
            threshold: threshold
        )
    }

    func snapX(_ x: CGFloat) -> CGFloat {
        Self.snap(x, to: xs, threshold: threshold)
    }

    func snapY(_ y: CGFloat) -> CGFloat {
        Self.snap(y, to: ys, threshold: threshold)
    }

    /// The smallest horizontal shift that puts either edge of a moved selection on a snap edge, or 0.
    func offsetX(minX: CGFloat, maxX: CGFloat) -> CGFloat {
        Self.offset(minValue: minX, maxValue: maxX, edges: xs, threshold: threshold)
    }

    /// The smallest vertical shift that puts either edge of a moved selection on a snap edge, or 0.
    func offsetY(minY: CGFloat, maxY: CGFloat) -> CGFloat {
        Self.offset(minValue: minY, maxValue: maxY, edges: ys, threshold: threshold)
    }

    private static func snap(_ value: CGFloat, to edges: [CGFloat], threshold: CGFloat) -> CGFloat {
        var best = value
        var bestDistance = threshold
        for edge in edges {
            let distance = abs(edge - value)
            if distance <= bestDistance {
                best = edge
                bestDistance = distance
            }
        }
        return best
    }

    private static func offset(minValue: CGFloat, maxValue: CGFloat, edges: [CGFloat], threshold: CGFloat) -> CGFloat {
        var best: CGFloat = 0
        var bestDistance = threshold + 1
        for edge in edges {
            for delta in [edge - minValue, edge - maxValue] where abs(delta) <= threshold && abs(delta) < bestDistance {
                best = delta
                bestDistance = abs(delta)
            }
        }
        return best
    }
}
