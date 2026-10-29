import CoreGraphics

/// Where a zoom segment looks from a moment on: the view pans to `point` so that it arrives just before `time`.
nonisolated struct ZoomFocus: Equatable, Sendable {
    /// Seconds from the start of the movie.
    var time: Double
    /// The middle of the zoomed view, normalized to the frame with a top-left origin.
    var point: CGPoint
}
