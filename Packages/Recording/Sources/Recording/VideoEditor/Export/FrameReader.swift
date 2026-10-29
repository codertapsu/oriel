import AVFoundation
import CoreGraphics
import OrielCore

/// Copy Text from Frame (PLAN §17): one frame of a movie, exactly as recorded, and the text in it.
nonisolated enum FrameReader {
    /// The frame shown at `time` (seconds), upright and at full size (or fitted in `maximumSize`), without the
    /// editor's zoom: the decoder is asked for that exact time (zero tolerance), not the nearest key frame. A time
    /// at or past the end reads the last frame.
    @concurrent
    static func image(of movie: URL, at time: Double, maximumSize: CGSize? = nil) async throws -> CGImage {
        let asset = AVURLAsset(url: movie, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let maximumSize {
            generator.maximumSize = maximumSize
        }
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let clamped = min(max(time.isFinite ? time : 0, 0), max(duration - 0.001, 0))
        do {
            return try await generator.image(at: CMTime(seconds: clamped, preferredTimescale: 60000)).image
        } catch {
            throw VideoEditorError.noFrame
        }
    }

    /// The text of the frame at `time`, one recognized line per line, top to bottom; empty when there is none.
    @concurrent
    static func text(of movie: URL, at time: Double, recognizer: any TextRecognizing) async throws -> String {
        let image = try await image(of: movie, at: time)
        let blocks = try await recognizer.recognize(image, mode: .fast, languages: [])
        return blocks.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
