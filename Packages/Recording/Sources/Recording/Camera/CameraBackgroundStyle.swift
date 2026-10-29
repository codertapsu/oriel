/// How "Blur camera background" treats the background (PLAN §17): blurred, or replaced by a color.
nonisolated enum CameraBackgroundStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case blur
    case color

    /// A dark grey that keeps the person in front, readable on light and dark screens.
    static let defaultColorHex = "#2C2C2E"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .blur: "Blurred"
        case .color: "Solid color"
        }
    }
}
