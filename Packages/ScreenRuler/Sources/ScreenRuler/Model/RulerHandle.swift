import CoreGraphics

/// A grab point of the measured area: four corners and four edges, named as they look on screen, so `top` is the
/// edge at the smaller y in global coordinates.
nonisolated enum RulerHandle: CaseIterable, Sendable, Equatable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var movesLeft: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var movesRight: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var movesTop: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var movesBottom: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    var isCorner: Bool {
        (movesLeft || movesRight) && (movesTop || movesBottom)
    }

    /// Where it sits on `rect`.
    func point(on rect: CGRect) -> CGPoint {
        CGPoint(
            x: movesLeft ? rect.minX : (movesRight ? rect.maxX : rect.midX),
            y: movesTop ? rect.minY : (movesBottom ? rect.maxY : rect.midY)
        )
    }
}
