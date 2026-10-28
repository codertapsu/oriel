import AVFoundation
import CoreMedia

/// Re-encodes a recording at a constant frame rate for video editors (PLAN §7.4).
///
/// ScreenCaptureKit delivers frames only when the screen changes, so recordings are variable frame rate. A video
/// composition whose frame timing does not follow the source track renders exactly one frame per `frameDuration`.
nonisolated enum ConstantFrameRateExporter {
    /// Writes `movie` re-encoded at `frameRate` to `output`, which must not exist yet. HEVC sources stay HEVC;
    /// everything else becomes H.264.
    @concurrent
    static func export(_ movie: URL, to output: URL, frameRate: Int) async throws {
        let asset = AVURLAsset(url: movie)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw RecordingError.exportFailed("The movie has no video.")
        }
        let isHEVC = try await track.load(.formatDescriptions).contains { $0.mediaSubType == .hevc }
        let duration = try await asset.load(.duration)
        var configuration = try await AVVideoComposition.Configuration(for: asset)
        configuration.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(frameRate, 1)))
        configuration.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
        let preset = isHEVC ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        try await MovieExporter.export(
            asset,
            preset: preset,
            to: output,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            videoComposition: AVVideoComposition(configuration: configuration)
        )
    }
}
