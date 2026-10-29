import CoreGraphics

/// The shape of a step marker: its body, the pointer wedge towards `Counter.pointer`, what a click hits and where a
/// marker goes when it is placed with a pointer. Pure, in image space.
nonisolated enum StepGeometry {
    /// Half the angle the pointer's base spans, seen from the centre.
    static let pointerHalfAngle: CGFloat = .pi * 0.18
    /// How far from the centre, in radii, the pointer's base corners sit: inside the body, so the wedge leaves it
    /// cleanly from both a circle and a rounded square.
    static let pointerBaseFraction: CGFloat = 0.9
    /// How far, in radii, a marker placed with a click sits from the point it points at.
    static let defaultPointerDistance: CGFloat = 2.6

    /// The pointer wedge: two base corners inside the body, then the tip. Nil when the marker shows no pointer.
    static func pointerTriangle(_ counter: Counter) -> (CGPoint, CGPoint, CGPoint)? {
        guard counter.showsPointer, let tip = counter.pointer else { return nil }
        let angle = atan2(tip.y - counter.center.y, tip.x - counter.center.x)
        let reach = counter.radius * pointerBaseFraction
        func corner(_ offset: CGFloat) -> CGPoint {
            CGPoint(x: counter.center.x + cos(angle + offset) * reach, y: counter.center.y + sin(angle + offset) * reach)
        }
        return (corner(pointerHalfAngle), corner(-pointerHalfAngle), tip)
    }

    /// The marker's body: its circle or rounded square.
    static func bodyPath(_ counter: Counter) -> CGPath {
        let rect = counter.circleRect
        switch counter.shape {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case .square:
            let radius = counter.radius * StepShape.squareCornerFraction
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }

    /// The pointer wedge as a closed path, if the marker has one.
    static func pointerPath(_ counter: Counter) -> CGPath? {
        guard let (first, second, tip) = pointerTriangle(counter) else { return nil }
        let path = CGMutablePath()
        path.move(to: first)
        path.addLine(to: tip)
        path.addLine(to: second)
        path.closeSubpath()
        return path
    }

    /// What the marker covers: the body, the pointer and the white outline around both.
    static func bounds(_ counter: Counter) -> CGRect {
        var rect = counter.circleRect
        if let (first, second, tip) = pointerTriangle(counter) {
            rect = rect.union(Geometry.rect(through: first, second)).union(CGRect(origin: tip, size: .zero))
        }
        let outline = counter.radius * 0.12
        return rect.insetBy(dx: -outline, dy: -outline)
    }

    /// Whether `point` lands on the body or the pointer, `tolerance` points off still counting.
    static func contains(_ counter: Counter, _ point: CGPoint, tolerance: CGFloat) -> Bool {
        let inBody: Bool = switch counter.shape {
        case .circle: hypot(point.x - counter.center.x, point.y - counter.center.y) <= counter.radius + tolerance
        case .square: counter.circleRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
        if inBody {
            return true
        }
        guard let (first, second, tip) = pointerTriangle(counter) else { return false }
        return isInside(point, triangle: (first, second, tip))
            || Geometry.distance(from: point, toSegmentFrom: first, to: tip) <= tolerance
            || Geometry.distance(from: point, toSegmentFrom: second, to: tip) <= tolerance
    }

    /// Where a marker placed by a click goes when it points at `tip`: a little way off, towards the middle of
    /// `bounds` (the image), so it stays in view, and fully inside `bounds` when there is room.
    static func defaultCenter(pointingAt tip: CGPoint, radius: CGFloat, in bounds: CGRect) -> CGPoint {
        var dx = bounds.midX - tip.x
        var dy = bounds.midY - tip.y
        let length = hypot(dx, dy)
        if length < 1 {
            // In the middle already: up and to the right, like a callout.
            dx = 1
            dy = -1
        }
        let norm = max(hypot(dx, dy), 0.0001)
        let distance = radius * defaultPointerDistance
        var center = CGPoint(x: tip.x + dx / norm * distance, y: tip.y + dy / norm * distance)
        let room = bounds.insetBy(dx: radius, dy: radius)
        if !room.isNull, room.width >= 0, room.height >= 0 {
            center.x = min(max(center.x, room.minX), room.maxX)
            center.y = min(max(center.y, room.minY), room.maxY)
        }
        return center
    }

    private static func isInside(_ point: CGPoint, triangle: (CGPoint, CGPoint, CGPoint)) -> Bool {
        func side(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
            (point.x - second.x) * (first.y - second.y) - (first.x - second.x) * (point.y - second.y)
        }
        let one = side(triangle.0, triangle.1)
        let two = side(triangle.1, triangle.2)
        let three = side(triangle.2, triangle.0)
        let hasNegative = one < 0 || two < 0 || three < 0
        let hasPositive = one > 0 || two > 0 || three > 0
        return !(hasNegative && hasPositive)
    }
}
