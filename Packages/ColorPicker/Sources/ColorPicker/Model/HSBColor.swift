import Foundation

/// Hue, saturation and brightness (HSV) of the clipped sRGB color, as design apps and `NSColor(hue:…)` take them:
/// hue in degrees, the others 0…1.
nonisolated struct HSBColor: Hashable, Sendable {
    var hue: Double
    var saturation: Double
    var brightness: Double
    var alpha: Double

    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }

    init(_ color: ColorValue) {
        let rgb = color.clamped
        let high = max(rgb.red, rgb.green, rgb.blue)
        let delta = high - min(rgb.red, rgb.green, rgb.blue)
        brightness = high
        saturation = high == 0 ? 0 : delta / high
        hue = HSLColor.hue(red: rgb.red, green: rgb.green, blue: rgb.blue)
        alpha = color.alpha
    }

    var color: ColorValue {
        let chroma = brightness * saturation
        let (red, green, blue) = HSLColor.sector(hue: hue, chroma: chroma)
        let match = brightness - chroma
        return ColorValue(red: red + match, green: green + match, blue: blue + match, alpha: alpha)
    }
}
