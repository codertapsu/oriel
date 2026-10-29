import AppKit

/// Between `ColorValue` and AppKit, always through extended sRGB, so that nothing is clipped on the way and AppKit
/// matches the color to each display when it draws.
nonisolated extension ColorValue {
    /// `color` in extended sRGB; nil for a pattern or catalog color that has no single value.
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.extendedSRGB) else { return nil }
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }

    var nsColor: NSColor {
        let components = [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        return NSColor(colorSpace: .extendedSRGB, components: components, count: 4)
    }

    var cgColor: CGColor {
        nsColor.cgColor
    }

    /// Black or white, whichever reads better on this color, for text drawn on a swatch.
    var legibleTextColor: NSColor {
        let shown = WCAGContrast.shown(self, on: .white)
        return WCAGContrast.ratio(shown, .black) >= WCAGContrast.ratio(shown, .white) ? .black : .white
    }
}
