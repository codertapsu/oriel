import AVFoundation
import ImageIO

/// Builds the video composition that shows a movie through its zoom plan (PLAN §17), with `ZoomCompositor`
/// drawing every frame. The same composition serves the editor's preview, the movie export and the GIF export,
/// so what is seen is what is written.
nonisolated enum ZoomComposition {
    /// The video a composition reads: its track, and its frames as shown.
    struct Source: Equatable, Sendable {
        let trackID: CMPersistentTrackID
        /// The frame size with the track's rotation applied, in pixels.
        let size: CGSize
        let orientation: CGImagePropertyOrientation
    }

    /// Frames come at `frameRate` per second, so a zoom glides even across a still screen, where a screen
    /// recording has no frames of its own. With `followsSourceTiming` (nothing is zoomed) they come when the
    /// source has them instead, which keeps a variable-frame-rate recording small.
    static func make(
        _ source: Source,
        duration: Double,
        plan: ZoomPlan,
        renderSize: CGSize,
        frameRate: Double,
        followsSourceTiming: Bool = false
    ) -> AVVideoComposition {
        // Rounded up, plus a millisecond, so the instruction never ends a rounding error before the movie does.
        let length = CMTime(value: CMTimeValue((max(duration, 0) * 60000).rounded(.up)) + 60, timescale: 60000)
        let instruction = ZoomInstruction(
            timeRange: CMTimeRange(start: .zero, duration: length),
            trackID: source.trackID,
            plan: plan,
            sourceSize: source.size,
            orientation: source.orientation
        )
        var configuration = AVVideoComposition.Configuration()
        configuration.customVideoCompositorClass = ZoomCompositor.self
        configuration.instructions = [instruction]
        configuration.renderSize = CGSize(width: max(renderSize.width.rounded(), 2), height: max(renderSize.height.rounded(), 2))
        configuration.frameDuration = CMTime(seconds: 1 / min(max(frameRate, 1), 120), preferredTimescale: 60000)
        configuration.sourceTrackIDForFrameTiming = followsSourceTiming ? source.trackID : kCMPersistentTrackID_Invalid
        configuration.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        configuration.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        configuration.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        return AVVideoComposition(configuration: configuration)
    }

    /// The preview's render size: the movie's size, at most `maximumLongEdge` pixels on its long edge, since the
    /// window shows it smaller anyway.
    static func previewSize(for sourceSize: CGSize, maximumLongEdge: CGFloat = 1920) -> CGSize {
        let long = max(sourceSize.width, sourceSize.height)
        guard long > maximumLongEdge, long > 0 else { return sourceSize }
        let factor = maximumLongEdge / long
        return CGSize(width: (sourceSize.width * factor).rounded(), height: (sourceSize.height * factor).rounded())
    }
}
