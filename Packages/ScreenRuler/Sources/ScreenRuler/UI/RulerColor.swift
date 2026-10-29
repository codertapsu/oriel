import AppKit

/// The ruler's line color, kept in settings as `#RRGGBB` (sRGB).
nonisolated enum RulerColor {
    static let fallback = NSColor.systemPink

    /// `#RRGGBB` or `RRGGBB` as a color; nil for anything else.
    static func color(hex text: String) -> NSColor? {
        let digits = text.trimmingCharacters(in: .whitespaces).drop { $0 == "#" }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat(value >> 16 & 0xFF) / 255,
            green: CGFloat(value >> 8 & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// The color as `#RRGGBB`, clipped to sRGB.
    static func hex(of color: NSColor) -> String {
        guard let srgb = color.usingColorSpace(.sRGB) else { return "#FF2D55" }
        let channels = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }
}
