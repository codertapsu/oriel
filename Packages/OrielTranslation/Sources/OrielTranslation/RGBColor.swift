import CoreGraphics
import Foundation

/// An opaque sRGB colour with WCAG contrast maths, for the overlay's fills and text.
struct RGBColor: Equatable, Sendable {
    /// 0…1 sRGB components.
    var red: Double
    var green: Double
    var blue: Double

    static let black = RGBColor(red: 0, green: 0, blue: 0)
    static let white = RGBColor(red: 1, green: 1, blue: 1)

    /// WCAG AA for normal text.
    static let minimumContrast = 4.5

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    init(bytes red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// WCAG 2 relative luminance.
    var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, 1…21.
    func contrastRatio(with other: RGBColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    /// The text colour for a background: the original text colour when it is readable on it (contrast ≥ 4.5:1),
    /// otherwise black or white, whichever contrasts more.
    static func readableText(on background: RGBColor, preferring candidate: RGBColor?) -> RGBColor {
        if let candidate, candidate.contrastRatio(with: background) >= minimumContrast {
            return candidate
        }
        return black.contrastRatio(with: background) >= white.contrastRatio(with: background) ? black : white
    }
}
