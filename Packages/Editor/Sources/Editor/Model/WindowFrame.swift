import CoreGraphics

/// A plain window frame around the screenshot: a title bar with the three traffic lights, light or dark.
nonisolated enum WindowFrame: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case light
    case dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The title bar's height, in points: a standard macOS title bar.
    var titleBarHeight: CGFloat {
        self == .none ? 0 : 28
    }

    /// The traffic lights' diameter, the gap between them and the first one's distance from the left edge.
    static let lightDiameter: CGFloat = 12
    static let lightSpacing: CGFloat = 8
    static let lightInset: CGFloat = 12
}
