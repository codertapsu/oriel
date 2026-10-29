import Foundation

/// A color as the Color Picker keeps it: gamma-encoded sRGB components and alpha.
///
/// The components are *extended* sRGB, so they may fall outside 0…1. A color picked on a Display P3 screen that sRGB
/// cannot show keeps its exact value that way (a vivid P3 red is about 1.09, −0.23, −0.15), and only the formats that
/// cannot say more, HEX, `rgb()` and HSL among them, clip it. `isInSRGBGamut` tells which colors those are.
///
/// Components stay finite and within ±`componentLimit`, far beyond any display's gamut, so a damaged file or an absurd
/// typed value can never turn the math into infinities.
nonisolated struct ColorValue: Hashable, Sendable {
    static let componentLimit = 10.0

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.bounded(red)
        self.green = Self.bounded(green)
        self.blue = Self.bounded(blue)
        self.alpha = alpha.isFinite ? min(max(alpha, 0), 1) : 1
    }

    private static func bounded(_ value: Double) -> Double {
        value.isFinite ? min(max(value, -componentLimit), componentLimit) : 0
    }

    init(_ components: SIMD3<Double>, alpha: Double = 1) {
        self.init(red: components.x, green: components.y, blue: components.z, alpha: alpha)
    }

    /// A color given in Display P3 (gamma-encoded), as `color(display-p3 …)` or `NSColor(displayP3Red:…)` write it.
    init(displayP3 components: SIMD3<Double>, alpha: Double = 1) {
        self.init(ColorSpaceMath.sRGB(fromDisplayP3: components), alpha: alpha)
    }

    static let black = ColorValue(red: 0, green: 0, blue: 0)
    static let white = ColorValue(red: 1, green: 1, blue: 1)

    /// Half an 8-bit step: a component this close to 0…1 still rounds into range, so the color counts as inside sRGB.
    static let gamutTolerance = 0.5 / 255

    var components: SIMD3<Double> {
        SIMD3(red, green, blue)
    }

    /// Whether sRGB can show the color: every component is within 0…1, give or take `gamutTolerance`.
    var isInSRGBGamut: Bool {
        [red, green, blue].allSatisfy { $0 >= -Self.gamutTolerance && $0 <= 1 + Self.gamutTolerance }
    }

    var isOpaque: Bool {
        alpha >= 1 - Self.gamutTolerance
    }

    /// The components clipped to 0…1, for the formats that can only say sRGB.
    var clamped: ColorValue {
        ColorValue(red: Self.unit(red), green: Self.unit(green), blue: Self.unit(blue), alpha: alpha)
    }

    /// The same color in Display P3, gamma-encoded. Outside P3 the components leave 0…1 too.
    var displayP3: SIMD3<Double> {
        ColorSpaceMath.displayP3(fromSRGB: components)
    }

    /// The clipped components as 0…255, as HEX and `rgb()` write them.
    var bytes: Bytes {
        Bytes(red: Self.byte(red), green: Self.byte(green), blue: Self.byte(blue), alpha: Self.byte(alpha))
    }

    /// Whether `other` looks the same: every component within half an 8-bit step. A color picked twice comes back
    /// through the display's color profile with slightly different digits, and the history should not list it twice.
    func isSameColor(as other: ColorValue) -> Bool {
        abs(red - other.red) < Self.gamutTolerance && abs(green - other.green) < Self.gamutTolerance
            && abs(blue - other.blue) < Self.gamutTolerance && abs(alpha - other.alpha) < Self.gamutTolerance
    }

    /// `#RRGGBB`, or `#RRGGBBAA` with `includesAlpha`, from the clipped components.
    func hex(uppercase: Bool = true, includesAlpha: Bool = false) -> String {
        let bytes = bytes
        var values = [bytes.red, bytes.green, bytes.blue]
        if includesAlpha {
            values.append(bytes.alpha)
        }
        let digits = values.map { value in
            let text = String(value, radix: 16, uppercase: uppercase)
            return text.count == 1 ? "0" + text : text
        }
        return "#" + digits.joined()
    }

    /// `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA`, with or without the `#`; nil for anything else.
    init?(hex text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? trimmed.dropFirst() : Substring(trimmed)
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        let expanded = digits.count <= 4 ? String(digits.flatMap { [$0, $0] }) : String(digits)
        var values: [Double] = []
        var index = expanded.startIndex
        while index < expanded.endIndex {
            let next = expanded.index(index, offsetBy: 2)
            guard let byte = UInt8(expanded[index ..< next], radix: 16) else { return nil }
            values.append(Double(byte) / 255)
            index = next
        }
        self.init(red: values[0], green: values[1], blue: values[2], alpha: values.count == 4 ? values[3] : 1)
    }

    /// The clipped components in 8 bits each.
    struct Bytes: Hashable, Sendable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func byte(_ value: Double) -> Int {
        Int((unit(value) * 255).rounded())
    }
}

/// Stored as its components, `{"red": 1, "green": 0.53, "blue": 0, "alpha": 1}`. A hex string (`"#FF8800"`) decodes
/// too, so a hand-written file or an older one that kept hex strings still opens.
nonisolated extension ColorValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            guard let color = ColorValue(hex: text) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "“\(text)” is not a hex color")
            }
            self = color
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            red: container.decode(Double.self, forKey: .red),
            green: container.decode(Double.self, forKey: .green),
            blue: container.decode(Double.self, forKey: .blue),
            alpha: container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }
}
