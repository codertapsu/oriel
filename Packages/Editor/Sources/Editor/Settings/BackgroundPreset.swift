import CoreGraphics

/// Ready-made backdrops for "social-ready" screenshots: a gradient or solid fill, a drop shadow and rounded
/// corners, with padding that scales with the image.
nonisolated enum BackgroundPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case ocean
    case sunset
    case mint
    case lavender
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

    private static func rgb(_ hex: Int) -> RGBAColor {
        RGBAColor(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
