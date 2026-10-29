import Foundation

/// The naive CMYK of the clipped sRGB color, each 0…1. Print uses a press profile instead, so this is for a quick
/// value only, as other color pickers give it.
nonisolated struct CMYKColor: Hashable, Sendable {
    var cyan: Double
    var magenta: Double
    var yellow: Double
    var key: Double

    init(cyan: Double, magenta: Double, yellow: Double, key: Double) {
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
        self.key = key
    }

    init(_ color: ColorValue) {
        let rgb = color.clamped
        let high = max(rgb.red, rgb.green, rgb.blue)
        key = 1 - high
        guard high > 0 else {
            cyan = 0
            magenta = 0
            yellow = 0
            return
        }
        cyan = (high - rgb.red) / high
        magenta = (high - rgb.green) / high
        yellow = (high - rgb.blue) / high
    }
}
