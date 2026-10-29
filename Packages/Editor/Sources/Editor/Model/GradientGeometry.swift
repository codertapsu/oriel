import CoreGraphics

/// Where a background gradient starts and ends, so it covers the canvas exactly at any size. Pure.
nonisolated enum GradientGeometry {
    /// The ends of a linear gradient running at `angle` degrees (0 left to right, 90 top to bottom, y down) through
    /// `rect`: the first colour at one corner's projection, the last at the opposite one, so no corner falls outside.
    static func linearEndpoints(angle: Double, in rect: CGRect) -> (start: CGPoint, end: CGPoint) {
        let radians = angle * .pi / 180
        let direction = CGVector(dx: cos(radians), dy: sin(radians))
        let reach = abs(direction.dx) * rect.width / 2 + abs(direction.dy) * rect.height / 2
        return (
            CGPoint(x: rect.midX - direction.dx * reach, y: rect.midY - direction.dy * reach),
            CGPoint(x: rect.midX + direction.dx * reach, y: rect.midY + direction.dy * reach)
        )
    }

    /// A radial gradient from `rect`'s centre (the first colour) to its corners (the last).
    static func radial(in rect: CGRect) -> (center: CGPoint, radius: CGFloat) {
        (CGPoint(x: rect.midX, y: rect.midY), hypot(rect.width, rect.height) / 2)
    }

    /// The colour `fraction` (0…1) of the way through evenly spaced `colors`, as Core Graphics blends it (linearly,
    /// in sRGB).
    static func color(at fraction: Double, through colors: [RGBAColor]) -> RGBAColor? {
        guard let first = colors.first else { return nil }
        guard colors.count > 1 else { return first }
        let position = min(max(fraction, 0), 1) * Double(colors.count - 1)
        let index = min(Int(position), colors.count - 2)
        let local = position - Double(index)
        let from = colors[index], to = colors[index + 1]
        func mix(_ lhs: Double, _ rhs: Double) -> Double {
            lhs + (rhs - lhs) * local
        }
        return RGBAColor(
            red: mix(from.red, to.red),
            green: mix(from.green, to.green),
            blue: mix(from.blue, to.blue),
            alpha: mix(from.alpha, to.alpha)
        )
    }
}
