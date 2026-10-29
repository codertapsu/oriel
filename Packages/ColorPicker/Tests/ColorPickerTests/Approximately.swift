@testable import ColorPicker

/// Whether two numbers agree to within `tolerance`.
func approximately(_ value: Double, _ expected: Double, _ tolerance: Double = 1e-6) -> Bool {
    abs(value - expected) <= tolerance
}

/// Whether two component triples agree to within `tolerance`.
func approximately(_ value: SIMD3<Double>, _ expected: SIMD3<Double>, _ tolerance: Double = 1e-6) -> Bool {
    approximately(value.x, expected.x, tolerance) && approximately(value.y, expected.y, tolerance)
        && approximately(value.z, expected.z, tolerance)
}

extension ColorValue {
    /// A test color from `#RRGGBB` or `#RRGGBBAA`.
    static func hex(_ text: String) -> ColorValue {
        guard let color = ColorValue(hex: text) else { preconditionFailure("\(text) is not a hex color") }
        return color
    }
}
