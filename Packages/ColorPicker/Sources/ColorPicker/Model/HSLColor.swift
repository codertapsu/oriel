import Foundation

/// Hue, saturation and lightness of the clipped sRGB color, as CSS `hsl()` takes them: hue in degrees, the others 0…1.
nonisolated struct HSLColor: Hashable, Sendable {
    var hue: Double
    var saturation: Double
    var lightness: Double
    var alpha: Double

    init(hue: Double, saturation: Double, lightness: Double, alpha: Double = 1) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.alpha = alpha
    }

    init(_ color: ColorValue) {
        let rgb = color.clamped
        let high = max(rgb.red, rgb.green, rgb.blue)
        let low = min(rgb.red, rgb.green, rgb.blue)
        let delta = high - low
        lightness = (high + low) / 2
        saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        hue = HSLColor.hue(red: rgb.red, green: rgb.green, blue: rgb.blue)
        alpha = color.alpha
    }

    var color: ColorValue {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let (red, green, blue) = Self.sector(hue: hue, chroma: chroma)
        let match = lightness - chroma / 2
        return ColorValue(red: red + match, green: green + match, blue: blue + match, alpha: alpha)
    }

    /// The hue (degrees, 0 ..< 360) that HSL and HSB share; 0 for grays.
    static func hue(red: Double, green: Double, blue: Double) -> Double {
        let high = max(red, green, blue)
        let delta = high - min(red, green, blue)
        guard delta > 0 else { return 0 }
        let degrees: Double = if high == red {
            60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == green {
            60 * ((blue - red) / delta + 2)
        } else {
            60 * ((red - green) / delta + 4)
        }
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// The red, green and blue of a hue at `chroma`, before the lightness or value offset is added.
    static func sector(hue: Double, chroma: Double) -> (Double, Double, Double) {
        let wrapped = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(wrapped.truncatingRemainder(dividingBy: 2) - 1))
        return switch Int(wrapped) {
        case 0: (chroma, second, 0)
        case 1: (second, chroma, 0)
        case 2: (0, chroma, second)
        case 3: (0, second, chroma)
        case 4: (second, 0, chroma)
        default: (chroma, 0, second)
        }
    }
}
