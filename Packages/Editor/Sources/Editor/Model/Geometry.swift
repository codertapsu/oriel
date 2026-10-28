import CoreGraphics

/// Pure plane geometry for drawing tools and hit-testing.
nonisolated enum Geometry {
    /// The shortest distance from `point` to the segment from `start` to `end`.
    static func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let along = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let clamped = min(max(along, 0), 1)
        return hypot(point.x - (start.x + clamped * dx), point.y - (start.y + clamped * dy))
    }

    /// `end` moved onto the nearest multiple of 45° around `start`, keeping its distance (Shift while drawing).
    static func snappedEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return end }
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        return CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
    }

    /// The rect spanned by a drag; a square on the side of the longer axis when `square` (Shift).
    static func rect(from start: CGPoint, to end: CGPoint, square: Bool) -> CGRect {
        var dx = end.x - start.x
        var dy = end.y - start.y
        if square {
            let side = max(abs(dx), abs(dy))
            dx = dx < 0 ? -side : side
            dy = dy < 0 ? -side : side
        }
        return CGRect(x: min(start.x, start.x + dx), y: min(start.y, start.y + dy), width: abs(dx), height: abs(dy))
    }

    /// `rect` with the edges that `handle` controls moved to `point`. The opposite edges stay put; dragging past
    /// them flips the rect instead of giving it a negative size.
    static func resize(_ rect: CGRect, moving handle: SelectionHandle, to point: CGPoint) -> CGRect {
        var minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        switch handle {
        case .topLeft, .left, .bottomLeft: minX = point.x
        case .topRight, .right, .bottomRight: maxX = point.x
        case .top, .bottom, .start, .end: break
        }
        switch handle {
        case .topLeft, .top, .topRight: minY = point.y
        case .bottomLeft, .bottom, .bottomRight: maxY = point.y
        case .left, .right, .start, .end: break
        }
        return CGRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY))
    }

    /// `point` moved from its place in `source` to the same relative place in `target`. A zero-sized axis
    /// keeps its offset instead of dividing by zero.
    static func map(_ point: CGPoint, from source: CGRect, to target: CGRect) -> CGPoint {
        let x = source.width > 0 ? target.minX + (point.x - source.minX) * target.width / source.width : point.x - source.minX + target.minX
        let y = source.height > 0 ? target.minY + (point.y - source.minY) * target.height / source.height : point.y - source.minY + target
            .minY
        return CGPoint(x: x, y: y)
    }

    /// The rect through two points, whatever their order.
    static func rect(through first: CGPoint, _ second: CGPoint) -> CGRect {
        CGRect(x: min(first.x, second.x), y: min(first.y, second.y), width: abs(second.x - first.x), height: abs(second.y - first.y))
    }

    /// How far `point` is from the outline of the ellipse inscribed in `rect` (an approximation that is exact
    /// for circles), and whether it is inside.
    static func ellipseOutlineDistance(from point: CGPoint, in rect: CGRect) -> (distance: CGFloat, isInside: Bool) {
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        guard radiusX > 0, radiusY > 0 else {
            let start = CGPoint(x: rect.minX, y: rect.minY)
            return (distance(from: point, toSegmentFrom: start, to: CGPoint(x: rect.maxX, y: rect.maxY)), false)
        }
        let normalizedX = (point.x - rect.midX) / radiusX
        let normalizedY = (point.y - rect.midY) / radiusY
        let radial = (normalizedX * normalizedX + normalizedY * normalizedY).squareRoot()
        return (abs(radial - 1) * min(radiusX, radiusY), radial < 1)
    }

    /// `rect` with each edge snapped to the nearest whole pixel at `scale` pixels per point.
    static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let minX = (rect.minX * scale).rounded() / scale
        let minY = (rect.minY * scale).rounded() / scale
        let maxX = (rect.maxX * scale).rounded() / scale
        let maxY = (rect.maxY * scale).rounded() / scale
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
