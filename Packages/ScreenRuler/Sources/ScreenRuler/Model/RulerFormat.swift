import CoreGraphics

/// How the ruler writes lengths: whole numbers where they are whole (`320 × 240 pt`), one decimal where a point
/// length falls between pixels (`320.5 pt`), always with a full stop, since it is copied into code and specs.
nonisolated enum RulerFormat {
    /// A length given in points, in `unit` on a display with `scale` pixels per point, without the unit.
    static func number(_ points: CGFloat, unit: RulerUnit, scale: CGFloat) -> String {
        let value = unit == .points ? points : points * max(scale, 1)
        let tenths = Int((abs(value) * 10).rounded())
        let sign = value < 0 && tenths > 0 ? "-" : ""
        return tenths % 10 == 0 ? "\(sign)\(tenths / 10)" : "\(sign)\(tenths / 10).\(tenths % 10)"
    }

    /// `120 pt`.
    static func length(_ points: CGFloat, unit: RulerUnit, scale: CGFloat) -> String {
        "\(number(points, unit: unit, scale: scale)) \(unit.symbol)"
    }

    /// `320 × 240 pt`: what ⌘C copies.
    static func size(_ size: CGSize, unit: RulerUnit, scale: CGFloat) -> String {
        "\(number(size.width, unit: unit, scale: scale)) × \(number(size.height, unit: unit, scale: scale)) \(unit.symbol)"
    }

    /// `x 120  y 48`: a position from the display's top-left corner.
    static func position(_ point: CGPoint, on display: RulerDisplay, unit: RulerUnit) -> String {
        let x = number(point.x - display.frame.minX, unit: unit, scale: display.scale)
        let y = number(point.y - display.frame.minY, unit: unit, scale: display.scale)
        return "x \(x)  y \(y)"
    }

    /// The other unit's size, for a second line under the main one: `640 × 480 px`.
    static func otherSize(_ size: CGSize, unit: RulerUnit, scale: CGFloat) -> String {
        self.size(size, unit: unit.toggled, scale: scale)
    }
}
