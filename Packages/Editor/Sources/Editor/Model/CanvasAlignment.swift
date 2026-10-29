import CoreGraphics

/// Where the image card sits when the canvas's aspect leaves more room than the padding: in one of nine places.
nonisolated enum CanvasAlignment: String, Codable, Sendable, CaseIterable, Identifiable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    var id: String {
        rawValue
    }

    /// The share of the spare width to the card's left: 0, ½ or 1.
    var horizontal: CGFloat {
        switch self {
        case .topLeading, .leading, .bottomLeading: 0
        case .top, .center, .bottom: 0.5
        case .topTrailing, .trailing, .bottomTrailing: 1
        }
    }

    /// The share of the spare height above the card: 0, ½ or 1.
    var vertical: CGFloat {
        switch self {
        case .topLeading, .top, .topTrailing: 0
        case .leading, .center, .trailing: 0.5
        case .bottomLeading, .bottom, .bottomTrailing: 1
        }
    }

    /// The name VoiceOver reads.
    var title: String {
        switch self {
        case .topLeading: "Top left"
        case .top: "Top"
        case .topTrailing: "Top right"
        case .leading: "Left"
        case .center: "Centre"
        case .trailing: "Right"
        case .bottomLeading: "Bottom left"
        case .bottom: "Bottom"
        case .bottomTrailing: "Bottom right"
        }
    }
}
