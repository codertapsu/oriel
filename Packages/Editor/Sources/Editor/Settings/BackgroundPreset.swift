import CoreGraphics

/// Ready-made backdrops for "social-ready" screenshots: a gradient (linear or radial) or solid fill, a drop shadow and
/// rounded corners, with padding that scales with the image. The desktop picture and images of the user's choice are
/// fills of their own (`BackgroundStyle.Fill.image`), and the user's own presets are `SavedBackground`s.
nonisolated enum BackgroundPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case ocean
    case sunset
    case mint
    case lavender
    case peach
    case sky
    case aurora
    case midnight
    case graphite
    case paper

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none: "None"
        case .ocean: "Ocean"
        case .sunset: "Sunset"
        case .mint: "Mint"
        case .lavender: "Lavender"
        case .peach: "Peach"
        case .sky: "Sky"
        case .aurora: "Aurora"
        case .midnight: "Midnight"
        case .graphite: "Graphite"
        case .paper: "Paper"
        }
    }

    /// Nil for `.none`, which removes the background and the padding.
    var style: BackgroundStyle? {
        switch self {
        case .none:
            nil
        case .ocean:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0x2E8BFF), Self.rgb(0x7A5CFF)])
        case .sunset:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0xFF7E5F), Self.rgb(0xFEB47B)])
        case .mint:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0x43E97B), Self.rgb(0x38F9D7)])
        case .lavender:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0xA18CD1), Self.rgb(0xFBC2EB)])
        case .peach:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0xFFDDE1), Self.rgb(0xEE9CA7)], angle: 120)
        case .sky:
            BackgroundStyle(fill: .gradient, colors: [Self.rgb(0xA1C4FD), Self.rgb(0xC2E9FB)], angle: 90)
        case .aurora:
            BackgroundStyle(fill: .radial, colors: [Self.rgb(0x5EE7DF), Self.rgb(0x6A5ACD), Self.rgb(0x1F1C4C)])
        case .midnight:
            BackgroundStyle(fill: .radial, colors: [Self.rgb(0x3A4A6B), Self.rgb(0x10131C)])
        case .graphite:
            BackgroundStyle(fill: .solid, colors: [Self.rgb(0x2C2C2E)])
        case .paper:
            BackgroundStyle(fill: .solid, colors: [Self.rgb(0xF2F2F7)])
        }
    }

    /// Padding for an image of `size` points: 8 % of the shorter side, between 24 and 96 points.
    static func defaultPadding(for size: CGSize) -> CGFloat {
        min(max((min(size.width, size.height) * 0.08).rounded(), 24), 96)
    }

    static func rgb(_ hex: Int) -> RGBAColor {
        RGBAColor(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
