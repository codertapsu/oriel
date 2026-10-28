import AppKit
import CoreGraphics

/// An sRGB colour with alpha, every component in 0…1. Documents and settings store colours this way, so a
/// saved `.oriel` file looks the same on every display.
nonisolated struct RGBAColor: Codable, Sendable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Converts any colour to sRGB. Nil for colours without RGB components (patterns, for example).
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ alpha: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Relative luminance (0 black … 1 white), to pick a legible colour on top of this one.
    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    static let red = RGBAColor(red: 1, green: 0.231, blue: 0.188)
    static let orange = RGBAColor(red: 1, green: 0.584, blue: 0)
    static let yellow = RGBAColor(red: 1, green: 0.8, blue: 0)
    static let green = RGBAColor(red: 0.204, green: 0.78, blue: 0.349)
    static let blue = RGBAColor(red: 0, green: 0.478, blue: 1)
    static let purple = RGBAColor(red: 0.686, green: 0.322, blue: 0.871)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)
    static let white = RGBAColor(red: 1, green: 1, blue: 1)

    /// The swatches the toolbar offers, in order, with the names VoiceOver reads.
    static let palette: [(color: RGBAColor, name: String)] = [
        (.red, "Red"), (.orange, "Orange"), (.yellow, "Yellow"), (.green, "Green"),
        (.blue, "Blue"), (.purple, "Purple"), (.black, "Black"), (.white, "White"),
    ]

    /// The palette name of this colour, or nil for a custom colour.
    var paletteName: String? {
        Self.palette.first { $0.color == self }?.name
    }
}
