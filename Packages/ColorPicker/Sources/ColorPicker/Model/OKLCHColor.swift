import Foundation

/// The color in OKLCH (Björn Ottosson's perceptual space in polar form, CSS `oklch()`): lightness 0…1, chroma from 0
/// (gray) up to about 0.4, and hue in degrees. Computed from the extended components, so a wide-gamut color keeps its
/// chroma instead of the clipped one's.
nonisolated struct OKLCHColor: Hashable, Sendable {
    var lightness: Double
    var chroma: Double
    var hue: Double
    var alpha: Double

    /// Below this chroma the hue means nothing (CSS calls it powerless), and it is written as 0.
    static let achromaticChroma = 0.000_2

    init(lightness: Double, chroma: Double, hue: Double, alpha: Double = 1) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
        self.alpha = alpha
    }

    init(_ color: ColorValue) {
        let lab = ColorSpaceMath.oklab(fromLinearSRGB: ColorSpaceMath.linear(color.components))
        let chroma = (lab.y * lab.y + lab.z * lab.z).squareRoot()
        lightness = lab.x
        if chroma < Self.achromaticChroma {
            self.chroma = 0
            hue = 0
        } else {
            self.chroma = chroma
            hue = ColorSpaceMath.hueDegrees(greenRed: lab.y, blueYellow: lab.z)
        }
        alpha = color.alpha
    }

    /// The (extended) sRGB color; a chroma sRGB cannot show leaves 0…1.
    var color: ColorValue {
        let radians = hue * .pi / 180
        let lab = SIMD3(lightness, chroma * cos(radians), chroma * sin(radians))
        return ColorValue(ColorSpaceMath.encoded(ColorSpaceMath.linearSRGB(fromOKLab: lab)), alpha: alpha)
    }
}
