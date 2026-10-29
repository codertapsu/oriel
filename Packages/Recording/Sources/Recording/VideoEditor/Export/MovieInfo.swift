import AVFoundation
import CoreGraphics
import ImageIO

/// What the video editor needs to know about a movie, read once when it opens (PLAN §17).
nonisolated struct MovieInfo: Equatable, Sendable {
    /// Frame rates a movie's rate is rounded to when it is within 5 % of one.
    private static let commonRates: [Double] = [24, 25, 30, 50, 60, 120]

    let url: URL
    /// Seconds.
    let duration: Double
    let videoTrackID: CMPersistentTrackID
    /// The frame size as shown, with the track's rotation applied, in pixels.
    let size: CGSize
    /// How the stored frames are turned to be shown upright.
    let orientation: CGImagePropertyOrientation
    /// The highest rate the video plays frames at. Screen recordings vary their rate, so this comes from the
    /// shortest frame rather than the average.
    let frameRate: Double
    let hasAudio: Bool
    /// The video's codec when it is one the editor exports, so export can offer it first.
    let codec: VideoCodec?

    /// Reads `url`. Throws `VideoEditorError.unreadable` for a file that is not a movie and `.noVideo` for one
    /// without video.
    @concurrent
    static func load(_ url: URL) async throws -> MovieInfo {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration: CMTime
        let videoTracks: [AVAssetTrack]
        let audioTracks: [AVAssetTrack]
        do {
            duration = try await asset.load(.duration)
            videoTracks = try await asset.loadTracks(withMediaType: .video)
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw VideoEditorError.unreadable
        }
        guard let track = videoTracks.first else { throw VideoEditorError.noVideo }
        guard duration.isNumeric, duration.seconds > 0 else { throw VideoEditorError.unreadable }
        let (naturalSize, transform, minimumFrameDuration, nominalRate, formats) = try await track.load(
            .naturalSize, .preferredTransform, .minFrameDuration, .nominalFrameRate, .formatDescriptions
        )
        let shown = naturalSize.applying(transform)
        let codec: VideoCodec? = if formats.contains(where: { $0.mediaSubType == .hevc }) {
            .hevc
        } else if formats.contains(where: { $0.mediaSubType == .h264 }) {
            .h264
        } else {
            nil
        }
        return MovieInfo(
            url: url,
            duration: duration.seconds,
            videoTrackID: track.trackID,
            size: CGSize(width: abs(shown.width).rounded(), height: abs(shown.height).rounded()),
            orientation: orientation(for: transform),
            frameRate: frameRate(minimumFrameDuration: minimumFrameDuration, nominalRate: Double(nominalRate)),
            hasAudio: !audioTracks.isEmpty,
            codec: codec
        )
    }

    /// The rate of the shortest frame, rounded to a common rate when close to one, between 1 and 120; the nominal
    /// rate, or 30, when the shortest frame is unknown.
    static func frameRate(minimumFrameDuration: CMTime, nominalRate: Double) -> Double {
        var rate = minimumFrameDuration.isNumeric && minimumFrameDuration.seconds > 0 ? 1 / minimumFrameDuration.seconds : nominalRate
        if !rate.isFinite || rate <= 0 {
            rate = 30
        }
        if let common = commonRates.first(where: { abs($0 - rate) / $0 < 0.05 }) {
            return common
        }
        return min(max(rate.rounded(), 1), 120)
    }

    /// The EXIF orientation of a track's preferred transform: quarter turns and mirroring.
    static func orientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a.rounded(), transform.b.rounded(), transform.c.rounded(), transform.d.rounded()) {
        case (0, 1, -1, 0): .right
        case (-1, 0, 0, -1): .down
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, 1): .upMirrored
        case (1, 0, 0, -1): .downMirrored
        case (0, 1, 1, 0): .leftMirrored
        case (0, -1, -1, 0): .rightMirrored
        default: .up
        }
    }
}
