import Foundation

/// APCA lightness contrast (Lc), the method drafted for WCAG 3, as APCA-W3 0.0.98G-4g computes it, shown next to the
/// WCAG 2.2 ratio as extra information. Unlike the ratio it depends on which color is the text: dark text on a light
/// background gives a positive Lc (up to about 106), light text on a dark one a negative Lc (down to about −108).
nonisolated enum APCAContrast {
    /// Lc of `text` on `background`, both clipped to sRGB; 0 when they are too close to tell apart.
    static func lightnessContrast(text: ColorValue, background: ColorValue) -> Double {
        var textY = screenLuminance(text)
        var backgroundY = screenLuminance(background)
        guard textY.isFinite, backgroundY.isFinite, min(textY, backgroundY) >= 0, max(textY, backgroundY) <= 1.1 else { return 0 }
        textY = softClampBlack(textY)
        backgroundY = softClampBlack(backgroundY)
        guard abs(backgroundY - textY) >= 0.000_5 else { return 0 }
        if backgroundY > textY {
            let contrast = (pow(backgroundY, 0.56) - pow(textY, 0.57)) * 1.14
            return contrast < 0.1 ? 0 : (contrast - 0.027) * 100
        }
        let contrast = (pow(backgroundY, 0.65) - pow(textY, 0.62)) * 1.14
        return contrast > -0.1 ? 0 : (contrast + 0.027) * 100
    }

    /// APCA's estimate of screen luminance: each 8-bit channel to the power 2.4, without sRGB's linear toe.
    static func screenLuminance(_ color: ColorValue) -> Double {
        let bytes = color.bytes
        let channel = { (value: Int) in pow(Double(value) / 255, 2.4) }
        return 0.212_672_9 * channel(bytes.red) + 0.715_152_2 * channel(bytes.green) + 0.072_175_0 * channel(bytes.blue)
    }

    /// What an Lc is enough for, after APCA's simple ("bronze") guidance.
    static func use(for lightnessContrast: Double) -> String {
        switch abs(lightnessContrast) {
        case 90...: "Preferred for body text"
        case 75...: "Enough for body text"
        case 60...: "Enough for content text, not body text"
        case 45...: "Enough for headlines and large text"
        case 30...: "Enough for placeholders and disabled text"
        case 15...: "Enough for dividers and large shapes, not text"
        default: "Too low to see reliably"
        }
    }

    /// `Lc 63.1`, or `Lc −68.5` (with a true minus sign) for light text on a dark background.
    static func text(_ lightnessContrast: Double) -> String {
        let rounded = (lightnessContrast * 10).rounded() / 10
        let magnitude = ColorFormatter.decimal(abs(rounded), places: 1)
        let shown = magnitude.contains(".") ? magnitude : magnitude + ".0"
        return rounded < 0 ? "Lc −\(shown)" : "Lc \(shown)"
    }

    /// Near-black luminance is lifted a little, as APCA models flare on real screens.
    private static func softClampBlack(_ luminance: Double) -> Double {
        let threshold = 0.022
        return luminance > threshold ? luminance : luminance + pow(threshold - luminance, 1.414)
    }
}
