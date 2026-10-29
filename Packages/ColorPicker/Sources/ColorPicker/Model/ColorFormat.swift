/// The ways the panel writes a color, in the order it lists them. The first ten copy with the number keys 1…9 and 0,
/// so the most used come first; the order is part of the interface, and new formats go at the end.
nonisolated enum ColorFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case hex
    case hexAlpha
    case rgb
    case rgba
    case hsl
    case hsb
    case oklch
    case swiftUI
    case nsColor
    case uiColor
    case rgbPercent
    case cmyk
    case displayP3

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .hex: "HEX"
        case .hexAlpha: "HEX + Alpha"
        case .rgb: "RGB"
        case .rgba: "RGBA"
        case .hsl: "HSL"
        case .hsb: "HSB"
        case .oklch: "OKLCH"
        case .swiftUI: "SwiftUI"
        case .nsColor: "NSColor"
        case .uiColor: "UIColor"
        case .rgbPercent: "RGB %"
        case .cmyk: "CMYK"
        case .displayP3: "Display P3"
        }
    }

    /// The digit that copies it in the panel (1…9, then 0 for the tenth), if it has one.
    var keyNumber: Int? {
        guard let index = Self.allCases.firstIndex(of: self), index < 10 else { return nil }
        return (index + 1) % 10
    }

    /// The format a digit key copies.
    static func format(forKeyNumber number: Int) -> ColorFormat? {
        allCases.first { $0.keyNumber == number }
    }

    /// Display P3 is only worth a row when it says something sRGB does not: for grays the two are the same numbers.
    func isShown(for color: ColorValue) -> Bool {
        guard self == .displayP3 else { return true }
        let p3 = color.displayP3
        let srgb = color.clamped.components
        return [p3.x - srgb.x, p3.y - srgb.y, p3.z - srgb.z].contains { abs($0) >= 0.000_5 }
    }
}
