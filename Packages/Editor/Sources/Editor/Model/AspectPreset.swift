/// The aspect choices the background tool offers, in menu order: free, the common ratios, the sizes social
/// networks recommend, and a custom pixel size.
nonisolated enum AspectPreset: String, CaseIterable, Sendable, Identifiable {
    case auto
    case widescreen
    case standard
    case square
    case portrait
    case story
    case classic
    case twitter
    case linkedIn
    case instagram
    case instagramPortrait
    case custom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .widescreen: "16:9"
        case .standard: "4:3"
        case .square: "1:1"
        case .portrait: "4:5"
        case .story: "9:16"
        case .classic: "3:2"
        case .twitter: "X (Twitter) · 1200 × 675"
        case .linkedIn: "LinkedIn · 1200 × 627"
        case .instagram: "Instagram · 1080 × 1080"
        case .instagramPortrait: "Instagram portrait · 1080 × 1350"
        case .custom: "Custom size"
        }
    }

    /// The aspect the preset stands for; nil for `.custom`, whose size the user types.
    var aspect: CanvasAspect? {
        switch self {
        case .auto: .auto
        case .widescreen: .ratio(width: 16, height: 9)
        case .standard: .ratio(width: 4, height: 3)
        case .square: .ratio(width: 1, height: 1)
        case .portrait: .ratio(width: 4, height: 5)
        case .story: .ratio(width: 9, height: 16)
        case .classic: .ratio(width: 3, height: 2)
        case .twitter: .pixels(width: 1200, height: 675)
        case .linkedIn: .pixels(width: 1200, height: 627)
        case .instagram: .pixels(width: 1080, height: 1080)
        case .instagramPortrait: .pixels(width: 1080, height: 1350)
        case .custom: nil
        }
    }

    /// Where the menu puts a divider before the preset.
    var startsGroup: Bool {
        self == .widescreen || self == .twitter || self == .custom
    }

    /// The preset that stands for `aspect`: a ratio or size of the list, else `.custom`.
    static func matching(_ aspect: CanvasAspect) -> AspectPreset {
        allCases.first { $0.aspect == aspect } ?? .custom
    }
}
