import CoreGraphics

/// A grab point of the area selection: four corners and four edges. Named in screen orientation, so `top` is the
/// edge at the selection's minY in CoreGraphics coordinates.
nonisolated enum SelectionHandle: CaseIterable, Sendable, Equatable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var movesMinX: Bool {
        self == .topLeft || self == .left || self == .bottomLeft
    }

    var movesMaxX: Bool {
        self == .topRight || self == .right || self == .bottomRight
    }

    var movesMinY: Bool {
        self == .topLeft || self == .top || self == .topRight
    }

    var movesMaxY: Bool {
        self == .bottomLeft || self == .bottom || self == .bottomRight
    }

    var isCorner: Bool {
        (movesMinX || movesMaxX) && (movesMinY || movesMaxY)
    }

    /// Where the handle is drawn on `rect`.
    func point(in rect: CGRect) -> CGPoint {
        let x = movesMinX ? rect.minX : (movesMaxX ? rect.maxX : rect.midX)
        let y = movesMinY ? rect.minY : (movesMaxY ? rect.maxY : rect.midY)
        return CGPoint(x: x, y: y)
    }
}
