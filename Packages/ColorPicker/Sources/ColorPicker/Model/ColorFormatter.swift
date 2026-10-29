import Foundation

/// Writes a color in each `ColorFormat`. Numbers always use a full stop, whatever the user's locale, because they are
/// pasted into CSS and code.
///
/// HEX, `rgb()`, HSL, HSB and CMYK can only say sRGB, so they write the clipped color. OKLCH and Display P3 write the
/// exact one. The code formats write sRGB too, unless the color is outside sRGB: then they use the Display P3
/// initializer, so the pasted code draws the color that was picked rather than its clipped neighbour.
///
/// HEX and RGB leave alpha to their twins, HEX + Alpha and RGBA; every other format carries it when it is below 1.
nonisolated enum ColorFormatter {
    static func string(_ format: ColorFormat, for color: ColorValue, uppercaseHex: Bool = true) -> String {
        switch format {
        case .hex: color.hex(uppercase: uppercaseHex)
        case .hexAlpha: color.hex(uppercase: uppercaseHex, includesAlpha: true)
        case .rgb: rgb(color, includesAlpha: false)
        case .rgba: rgb(color, includesAlpha: true)
        case .rgbPercent: rgbPercent(color)
        case .hsl: hsl(color)
        case .hsb: hsb(color)
        case .cmyk: cmyk(color)
        case .oklch: oklch(color)
        case .displayP3: displayP3(color)
        case .swiftUI: swiftUI(color)
        case .nsColor: nsColor(color)
        case .uiColor: uiColor(color)
        }
    }

    /// The format's title in the panel; a code format says when it writes Display P3.
    static func title(_ format: ColorFormat, for color: ColorValue) -> String {
        switch format {
        case .swiftUI, .nsColor, .uiColor: color.isInSRGBGamut ? format.title : "\(format.title) · P3"
        default: format.title
        }
    }

    // MARK: CSS

    /// `rgb(255, 136, 0)`, or `rgba(255, 136, 0, 0.5)`.
    private static func rgb(_ color: ColorValue, includesAlpha: Bool) -> String {
        let bytes = color.bytes
        let values = "\(bytes.red), \(bytes.green), \(bytes.blue)"
        return includesAlpha ? "rgba(\(values), \(alphaText(color.alpha)))" : "rgb(\(values))"
    }

    /// `rgb(100%, 53.3%, 0%)`, with alpha as a fourth value when the color is not opaque.
    private static func rgbPercent(_ color: ColorValue) -> String {
        let clipped = color.clamped
        let values = [clipped.red, clipped.green, clipped.blue].map { decimal($0 * 100, places: 1) + "%" }
        guard color.isOpaque else { return "rgba(\(values.joined(separator: ", ")), \(alphaText(color.alpha)))" }
        return "rgb(\(values.joined(separator: ", ")))"
    }

    /// `hsl(32, 100%, 50%)`, or `hsla(…, 0.5)`.
    private static func hsl(_ color: ColorValue) -> String {
        let hsl = HSLColor(color)
        let values = "\(degrees(hsl.hue)), \(percent(hsl.saturation)), \(percent(hsl.lightness))"
        return color.isOpaque ? "hsl(\(values))" : "hsla(\(values), \(alphaText(color.alpha)))"
    }

    /// `hsb(32, 100%, 100%)`: not CSS, but how design apps name the numbers.
    private static func hsb(_ color: ColorValue) -> String {
        let hsb = HSBColor(color)
        let values = "\(degrees(hsb.hue)), \(percent(hsb.saturation)), \(percent(hsb.brightness))"
        return color.isOpaque ? "hsb(\(values))" : "hsba(\(values), \(alphaText(color.alpha)))"
    }

    /// `cmyk(0%, 47%, 100%, 0%)`.
    private static func cmyk(_ color: ColorValue) -> String {
        let cmyk = CMYKColor(color)
        return "cmyk(\([cmyk.cyan, cmyk.magenta, cmyk.yellow, cmyk.key].map(percent).joined(separator: ", ")))"
    }

    /// `oklch(0.744 0.181 56.5)`, or `oklch(… / 0.5)`.
    private static func oklch(_ color: ColorValue) -> String {
        let lch = OKLCHColor(color)
        let values = "\(decimal(lch.lightness, places: 3)) \(decimal(lch.chroma, places: 3)) \(decimal(lch.hue, places: 1))"
        return "oklch(\(values)\(slashAlpha(color)))"
    }

    /// `color(display-p3 0.939 0.558 0.206)`, or `color(… / 0.5)`.
    private static func displayP3(_ color: ColorValue) -> String {
        let p3 = color.displayP3
        let values = [p3.x, p3.y, p3.z].map { decimal($0, places: 3) }.joined(separator: " ")
        return "color(display-p3 \(values)\(slashAlpha(color)))"
    }

    // MARK: Code

    /// `Color(red: 1, green: 0.533, blue: 0)`; `Color(.displayP3, red: …)` outside sRGB.
    private static func swiftUI(_ color: ColorValue) -> String {
        let opacity = color.isOpaque ? "" : ", opacity: \(decimal(color.alpha, places: 3))"
        guard color.isInSRGBGamut else { return "Color(.displayP3, \(labelled(color.displayP3))\(opacity))" }
        return "Color(\(labelled(color.clamped.components))\(opacity))"
    }

    /// `NSColor(srgbRed: 1, green: 0.533, blue: 0, alpha: 1)`; `NSColor(displayP3Red: …)` outside sRGB.
    private static func nsColor(_ color: ColorValue) -> String {
        let alpha = "alpha: \(decimal(color.alpha, places: 3))"
        guard color.isInSRGBGamut else { return "NSColor(displayP3Red: \(continued(color.displayP3)), \(alpha))" }
        return "NSColor(srgbRed: \(continued(color.clamped.components)), \(alpha))"
    }

    /// `UIColor(red: 1, green: 0.533, blue: 0, alpha: 1)`; `UIColor(displayP3Red: …)` outside sRGB.
    private static func uiColor(_ color: ColorValue) -> String {
        let alpha = "alpha: \(decimal(color.alpha, places: 3))"
        guard color.isInSRGBGamut else { return "UIColor(displayP3Red: \(continued(color.displayP3)), \(alpha))" }
        return "UIColor(\(labelled(color.clamped.components)), \(alpha))"
    }

    /// `red: 1, green: 0.533, blue: 0`.
    private static func labelled(_ components: SIMD3<Double>) -> String {
        "red: " + continued(components)
    }

    /// `1, green: 0.533, blue: 0`: the components after a first label that names the color space (`srgbRed:`).
    private static func continued(_ components: SIMD3<Double>) -> String {
        let values = [components.x, components.y, components.z].map { decimal($0, places: 3) }
        return "\(values[0]), green: \(values[1]), blue: \(values[2])"
    }

    // MARK: Numbers

    /// `value` rounded to `places` decimals, without trailing zeros (`0.5`, `1`, `-0.227`), never `-0`. A value that is
    /// not finite reads as 0, and the magnitude is capped, so the conversion to whole numbers cannot overflow.
    static func decimal(_ value: Double, places: Int) -> String {
        guard value.isFinite else { return "0" }
        let factor = pow(10, Double(places))
        let scaled = (min(max(value, -1e9), 1e9) * factor).rounded()
        guard scaled != 0 else { return "0" }
        let negative = scaled < 0
        let digits = String(Int(abs(scaled)))
        let padded = String(repeating: "0", count: max(0, places + 1 - digits.count)) + digits
        let whole = padded.dropLast(places)
        var fraction = padded.suffix(places)
        while fraction.last == "0" {
            fraction = fraction.dropLast()
        }
        return (negative ? "-" : "") + whole + (fraction.isEmpty ? "" : "." + fraction)
    }

    /// Alpha with up to three decimals, enough to tell every 8-bit step apart.
    static func alphaText(_ alpha: Double) -> String {
        decimal(alpha, places: 3)
    }

    private static func slashAlpha(_ color: ColorValue) -> String {
        color.isOpaque ? "" : " / \(alphaText(color.alpha))"
    }

    private static func percent(_ unit: Double) -> String {
        "\(Int((unit * 100).rounded()))%"
    }

    /// Whole degrees, 0 ..< 360: 359.6 rounds to 0, not 360.
    private static func degrees(_ hue: Double) -> String {
        String(Int(hue.rounded()) % 360)
    }
}
