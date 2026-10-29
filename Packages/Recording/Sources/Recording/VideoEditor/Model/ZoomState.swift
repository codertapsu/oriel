import CoreGraphics

/// How one frame is zoomed: by how much, and which point of the frame is in the middle. Pure.
nonisolated struct ZoomState: Equatable, Sendable {
    /// The whole frame.
    static let identity = ZoomState(scale: 1, center: CGPoint(x: 0.5, y: 0.5))

    /// 1 shows the whole frame; 2 shows a quarter of it, twice as large.
    var scale: Double
    /// The middle of the part shown, normalized to the frame with a top-left origin. Kept inside the frame by
    /// `ZoomTransform`, so edges never show black.
    var center: CGPoint

    /// Whether the frame is shown as it is.
    var isIdentity: Bool {
        scale <= 1.0001
    }
}
