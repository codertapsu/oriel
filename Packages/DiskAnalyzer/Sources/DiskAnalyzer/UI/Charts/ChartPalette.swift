import AppKit

/// The charts' colors: one system color per item of the shown folder, so everything inside it shares that color and
/// the big consumers read as big areas of one color; lighter (darker in Dark Mode) with each ring or level. System
/// colors adapt to the appearance and to Increase Contrast. Call while drawing, so dynamic colors resolve for the
/// view's appearance.
enum ChartPalette {
    private static let branches: [NSColor] = [
        .systemBlue, .systemPurple, .systemOrange, .systemTeal, .systemPink, .systemGreen, .systemIndigo, .systemRed,
        .systemYellow, .systemMint, .systemCyan, .systemBrown,
    ]

    /// `sibling` is the item's place among its folder's items: below the first level, neighbours turn the branch's hue a
    /// little one way or the other, so they stay one family but read as separate items.
    static func fill(branch: Int, depth: Int, sibling: Int = 0, kind: ScanNodeKind?) -> NSColor {
        switch kind {
        case .system?:
            return NSColor.systemGray.blended(withFraction: 0.15, of: .textBackgroundColor) ?? .systemGray
        case .unaccounted?:
            return NSColor.systemGray.blended(withFraction: 0.55, of: .textBackgroundColor) ?? .systemGray
        case .smallFiles?, nil:
            return NSColor.systemGray.blended(withFraction: 0.35, of: .textBackgroundColor) ?? .systemGray
        default:
            guard branch >= 0 else { return .systemGray }
            let base = shifted(branches[branch % branches.count], by: depth > 1 ? sibling : 0)
            let fraction = min(0.55, 0.11 * Double(max(0, depth - 1)))
            return base.blended(withFraction: fraction, of: .textBackgroundColor) ?? base
        }
    }

    /// The largest item keeps the branch's hue; the next ones turn it a little each way in turn, up to ±6 %.
    private static let turns: [CGFloat] = [0, 1, -1, 2, -2]

    private static func shifted(_ color: NSColor, by sibling: Int) -> NSColor {
        guard sibling > 0, let rgb = color.usingColorSpace(.sRGB) else { return color }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let turn = turns[sibling % turns.count] * 0.03
        return NSColor(
            colorSpace: .sRGB,
            hue: (hue + turn + 1).truncatingRemainder(dividingBy: 1),
            saturation: saturation,
            brightness: brightness,
            alpha: alpha
        )
    }

    /// The lines between segments and tiles: the background, so items read as separate shapes.
    static var separator: NSColor {
        .textBackgroundColor
    }

    static var hoverOverlay: NSColor {
        NSColor.white.withAlphaComponent(0.28)
    }

    static var selectionStroke: NSColor {
        .keyboardFocusIndicatorColor
    }

    /// The color of a label drawn on `fill`: dark on light colors, light on dark ones.
    static func text(on fill: NSColor) -> NSColor {
        guard let rgb = fill.usingColorSpace(.sRGB) else { return .labelColor }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance > 0.6 ? NSColor.black.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.95)
    }
}
