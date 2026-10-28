import CoreGraphics
import OrielCore

/// A finished interactive capture before it is delivered: the result, its HDR version when one was captured, and
/// whether the user asked for copy or save on the overlay instead of the after-capture action.
nonisolated struct CapturedImage: Sendable {
    let result: CaptureResult
    let hdrImage: CGImage?
    let intent: OverlayIntent
}
