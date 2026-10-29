import CoreGraphics

/// What the ruler counts in: points, the size macOS lays things out in, or the display's pixels (two per point on a
/// Retina display). Measurements also snap to whole units of the one chosen.
nonisolated enum RulerUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case points
    case pixels

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .points: "Points"
        case .pixels: "Pixels"
        }
    }

    var symbol: String {
        switch self {
        case .points: "pt"
        case .pixels: "px"
        }
    }

    var toggled: RulerUnit {
        self == .points ? .pixels : .points
    }

    /// One unit, in points, on a display with `scale` pixels per point.
    func step(scale: CGFloat) -> CGFloat {
        self == .points ? 1 : 1 / max(scale, 1)
    }
}
