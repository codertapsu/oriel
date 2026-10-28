import CoreGraphics

/// A display for the pure crop and layout math: where it is and how many pixels each point has.
nonisolated struct DisplayFrame: Sendable, Equatable {
    let id: CGDirectDisplayID
    /// Global CoreGraphics points (top-left origin of the primary display).
    let frame: CGRect
    /// Pixels per point (`backingScaleFactor`, ScreenCaptureKit's `pointPixelScale`).
    let scale: CGFloat

    /// The display's size in pixels.
    var pixelSize: CGSize {
        CGSize(width: (frame.width * scale).rounded(), height: (frame.height * scale).rounded())
    }
}
