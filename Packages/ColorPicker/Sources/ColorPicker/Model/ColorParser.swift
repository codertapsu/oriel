import Foundation

/// Reads a color typed or pasted into the panel: HEX (`#F80`, `FF8800`, `#FF880080`), the CSS functions `rgb()`,
/// `rgba()`, `hsl()`, `hsla()`, `oklch()` and `color(display-p3 …)` in their comma and space forms, `hsb()`, `cmyk()`,
/// and the Swift initializers the panel writes (`Color(red: 1, green: 0.5, blue: 0)`, `NSColor(displayP3Red: …)`).
/// So every format the panel copies reads back.
nonisolated enum ColorParser {
    static func parse(_ text: String) -> ColorValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { return nil }
        if let color = ColorValue(hex: trimmed) {
            return color
        }
        let lower = trimmed.lowercased()
        if lower.contains("red:") {
            return code(lower)
        }
        guard let open = lower.firstIndex(of: "("), lower.hasSuffix(")") else { return nil }
        let name = lower[..<open].trimmingCharacters(in: .whitespaces)
        let arguments = String(lower[lower.index(after: open) ..< lower.index(before: lower.endIndex)])
        switch name {
        case "rgb", "rgba": return rgb(arguments)
        case "hsl", "hsla": return hsl(arguments)
        case "hsb", "hsba", "hsv", "hsva": return hsb(arguments)
        case "cmyk": return cmyk(arguments)
        case "oklch": return oklch(arguments)
        case "color": return colorFunction(arguments)
        default: return nil
        }
    }

    // MARK: Functions

    private static func rgb(_ arguments: String) -> ColorValue? {
        guard let parts = split(arguments, count: 3),
              let red = unit(parts.values[0], scale: 255), let green = unit(parts.values[1], scale: 255),
              let blue = unit(parts.values[2], scale: 255)
        else { return nil }
        return ColorValue(red: red, green: green, blue: blue, alpha: parts.alpha)
    }

    private static func hsl(_ arguments: String) -> ColorValue? {
        guard let parts = split(arguments, count: 3), let hue = degrees(parts.values[0]),
              let saturation = unit(parts.values[1], scale: 100), let lightness = unit(parts.values[2], scale: 100)
        else { return nil }
        return HSLColor(hue: hue, saturation: saturation, lightness: lightness, alpha: parts.alpha).color
    }

    private static func hsb(_ arguments: String) -> ColorValue? {
        guard let parts = split(arguments, count: 3), let hue = degrees(parts.values[0]),
              let saturation = unit(parts.values[1], scale: 100), let brightness = unit(parts.values[2], scale: 100)
        else { return nil }
        return HSBColor(hue: hue, saturation: saturation, brightness: brightness, alpha: parts.alpha).color
    }

    /// `cmyk(c, m, y, k)`, each a percentage or 0…100, read back the naive way the panel writes it.
    private static func cmyk(_ arguments: String) -> ColorValue? {
        guard let parts = split(arguments, count: 4) else { return nil }
        let inks = parts.values.compactMap { unit($0, scale: 100) }
        guard inks.count == 4 else { return nil }
        let white = 1 - inks[3]
        return ColorValue(red: (1 - inks[0]) * white, green: (1 - inks[1]) * white, blue: (1 - inks[2]) * white, alpha: parts.alpha)
    }

    /// `oklch(L C H)`: L as 0…1 or a percentage, C as a number (100% is 0.4, as in CSS), H in degrees.
    private static func oklch(_ arguments: String) -> ColorValue? {
        guard let parts = split(arguments, count: 3), let lightness = unit(parts.values[0], scale: 1),
              let chroma = number(parts.values[1], percentOf: 0.4), (0 ... 1).contains(chroma), let hue = degrees(parts.values[2])
        else { return nil }
        return OKLCHColor(lightness: lightness, chroma: chroma, hue: hue, alpha: parts.alpha).color
    }

    /// `color(display-p3 r g b)` and `color(srgb r g b)`, each 0…1 or a percentage.
    private static func colorFunction(_ arguments: String) -> ColorValue? {
        let words = arguments.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard words.count == 2, let parts = split(String(words[1]), count: 3) else { return nil }
        let values = parts.values.compactMap { number($0, percentOf: 1) }
        guard values.count == 3, values.allSatisfy(isPlausible) else { return nil }
        let components = SIMD3(values[0], values[1], values[2])
        switch words[0] {
        case "display-p3": return ColorValue(displayP3: components, alpha: parts.alpha)
        case "srgb": return ColorValue(components, alpha: parts.alpha)
        default: return nil
        }
    }

    /// The labelled components of a Swift initializer; P3 when it names Display P3.
    private static func code(_ text: String) -> ColorValue? {
        func value(after label: String) -> Double? {
            guard let range = text.range(of: label) else { return nil }
            let rest = text[range.upperBound...].drop { $0.isWhitespace }
            guard let value = Double(rest.prefix { "0123456789.-+e".contains($0) }), value.isFinite else { return nil }
            return value
        }
        guard let red = value(after: "red:"), let green = value(after: "green:"), let blue = value(after: "blue:"),
              [red, green, blue].allSatisfy(isPlausible)
        else { return nil }
        let alpha = value(after: "alpha:") ?? value(after: "opacity:") ?? 1
        guard (0 ... 1).contains(alpha) else { return nil }
        let components = SIMD3(red, green, blue)
        return text.contains("displayp3") ? ColorValue(displayP3: components, alpha: alpha) : ColorValue(components, alpha: alpha)
    }

    // MARK: Arguments

    /// Three components and the alpha, from `255, 136, 0`, `255 136 0 / 50%` or `255,136,0,0.5`; alpha is 1 when absent.
    private static func split(_ arguments: String, count: Int) -> (values: [String], alpha: Double)? {
        let tokens = arguments.replacingOccurrences(of: "/", with: " / ")
            .split { $0 == "," || $0.isWhitespace }
            .map(String.init)
        var values = tokens
        var alphaToken: String?
        if let slash = tokens.firstIndex(of: "/") {
            guard slash == count, tokens.count == count + 2 else { return nil }
            values = Array(tokens[..<slash])
            alphaToken = tokens[slash + 1]
        } else if tokens.count == count + 1 {
            values = Array(tokens[..<count])
            alphaToken = tokens[count]
        }
        guard values.count == count else { return nil }
        guard let alphaToken else { return (values, 1) }
        guard let alpha = unit(alphaToken, scale: 1) else { return nil }
        return (values, alpha)
    }

    /// A number out of `scale`, or a percentage, as 0…1; nil when it is not a number or out of range.
    private static func unit(_ token: String, scale: Double) -> Double? {
        guard let value = number(token, percentOf: 1, plainScale: scale), (0 ... 1).contains(value) else { return nil }
        return value
    }

    /// `token` divided by `plainScale`, or a percentage of `percentOf`.
    private static func number(_ token: String, percentOf full: Double, plainScale: Double = 1) -> Double? {
        let value: Double? = if token.hasSuffix("%") {
            Double(token.dropLast()).map { $0 / 100 * full }
        } else {
            Double(token).map { $0 / plainScale }
        }
        // `Double` reads "inf" and "nan" too; neither is a color.
        guard let value, value.isFinite else { return nil }
        return value
    }

    /// A component a real color can have in sRGB or Display P3, with room for wide-gamut values.
    private static func isPlausible(_ component: Double) -> Bool {
        (-2 ... 3).contains(component)
    }

    /// Degrees, written bare or with `deg`.
    private static func degrees(_ token: String) -> Double? {
        guard let value = Double(token.hasSuffix("deg") ? String(token.dropLast(3)) : token), value.isFinite else { return nil }
        return value
    }
}
