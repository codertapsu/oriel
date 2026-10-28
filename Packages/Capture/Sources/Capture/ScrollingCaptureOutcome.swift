import CoreGraphics

/// How a scrolling capture session ended.
nonisolated enum ScrollingCaptureOutcome: Sendable {
    /// The stitched image. `stoppedEarly` when a later frame could not be lined up and the rest was kept.
    case finished(CGImage, scale: CGFloat, stoppedEarly: Bool)
    case cancelled
    /// The very first scroll could not be lined up: fail fast and suggest manual mode (PLAN §7.3, item 10).
    case lowConfidence
    case failed(String)
}
