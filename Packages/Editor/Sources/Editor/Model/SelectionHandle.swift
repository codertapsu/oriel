import CoreGraphics

/// A drag handle on the selected item: the eight around a box, or the two ends of a line or arrow.
nonisolated enum SelectionHandle: CaseIterable, Sendable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
    case start
    case end

    /// The handles of rectangles, ellipses and effect regions.
    static let boxHandles: [SelectionHandle] = [.topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
    /// The handles of pen and highlighter strokes, which scale.
    static let cornerHandles: [SelectionHandle] = [.topLeft, .topRight, .bottomRight, .bottomLeft]

    /// Where a box handle sits on `rect` (image space, y down, so `top` is `minY`). Line ends have no fixed spot.
    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        case .start: CGPoint(x: rect.minX, y: rect.minY)
        case .end: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}
