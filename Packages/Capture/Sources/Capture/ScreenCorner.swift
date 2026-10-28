/// A corner of a screen's visible frame, where the Quick Access Overlay stacks its cards.
nonisolated enum ScreenCorner: String, CaseIterable, Codable, Sendable, Identifiable {
    case bottomRight
    case bottomLeft
    case topRight
    case topLeft

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .bottomRight: "Bottom Right"
        case .bottomLeft: "Bottom Left"
        case .topRight: "Top Right"
        case .topLeft: "Top Left"
        }
    }

    var isBottom: Bool {
        self == .bottomRight || self == .bottomLeft
    }

    var isRight: Bool {
        self == .bottomRight || self == .topRight
    }
}
