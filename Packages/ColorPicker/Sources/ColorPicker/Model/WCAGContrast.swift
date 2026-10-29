import Foundation

/// WCAG 2.2 contrast (Understanding SC 1.4.3, the "relative luminance" and "contrast ratio" definitions): the
/// luminance of each sRGB color on linear light, and (lighter + 0.05) / (darker + 0.05), from 1:1 to 21:1. WCAG is
/// defined in sRGB, so both colors are clipped first. WCAG 2.2 linearizes below 0.04045, as the sRGB standard does,
/// where earlier versions printed 0.03928; the two give the same ratios at the precision WCAG uses.
nonisolated enum WCAGContrast {
    static func relativeLuminance(of color: ColorValue) -> Double {
        let rgb = color.clamped
        return 0.2126 * ColorSpaceMath.linear(rgb.red) + 0.7152 * ColorSpaceMath.linear(rgb.green)
            + 0.0722 * ColorSpaceMath.linear(rgb.blue)
    }

    /// The ratio between two opaque colors; the order does not matter.
    static func ratio(_ first: ColorValue, _ second: ColorValue) -> Double {
        let one = relativeLuminance(of: first)
        let two = relativeLuminance(of: second)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    /// Text drawn in `text` on `background`, as the eye sees it: a translucent text color is blended over the
    /// background (in sRGB, as browsers blend), and the background counts as opaque, because what lies under it is not
    /// known.
    static func shown(_ text: ColorValue, on background: ColorValue) -> ColorValue {
        let base = background.clamped
        let top = text.clamped
        let alpha = text.alpha
        return ColorValue(
            red: top.red * alpha + base.red * (1 - alpha),
            green: top.green * alpha + base.green * (1 - alpha),
            blue: top.blue * alpha + base.blue * (1 - alpha)
        )
    }

    /// The ratio as WCAG tools show it, cut (not rounded) to two decimals, so 4.499:1 never reads as a passing 4.50:1.
    static func ratioText(_ ratio: Double) -> String {
        guard ratio.isFinite else { return "—" }
        // The tiny nudge keeps a ratio such as 4.54, stored as 4.5399999…, from showing as 4.53.
        let hundredths = Int((min(max(ratio, 0), 100) * 100 + 1e-9).rounded(.down))
        let fraction = hundredths % 100
        return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction):1"
    }
}
