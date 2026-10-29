import CoreGraphics

/// The body of a step marker.
nonisolated enum StepShape: String, Codable, Sendable, CaseIterable, Identifiable {
    case circle
    /// A square with rounded corners, the size of the circle.
    case square

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        }
    }

    var symbolName: String {
        switch self {
        case .circle: "1.circle.fill"
        case .square: "1.square.fill"
        }
    }

    /// The rounded square's corner radius, as a fraction of the marker's radius.
    static let squareCornerFraction: CGFloat = 0.32
}
