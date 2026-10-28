import AVFoundation

/// Writes an asset to an MP4 with `AVAssetExportSession`'s async API (`export(to:as:)`, macOS 15+; the callback
/// API is deprecated in macOS 27, S8). Runs off the main actor.
nonisolated enum MovieExporter {
    /// Exports `asset` to `output`, which must not exist yet. `timeRange` trims; `videoComposition` re-renders.
    ///
    /// Callers pass the full range even when they do not trim: without one, a video-composition export of a movie
    /// whose last frame is held (a still screen) ended at that frame instead of the track's end when other exports
    /// ran at the same time (macOS 27.0.1, seen in the test suite).
    @concurrent
    static func export(
        _ asset: AVAsset,
        preset: String,
        to output: URL,
        timeRange: CMTimeRange? = nil,
        videoComposition: AVVideoComposition? = nil
    ) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw RecordingError.exportFailed("The movie cannot be exported with \(preset).")
        }
        if let timeRange {
            session.timeRange = timeRange
        }
        if let videoComposition {
            session.videoComposition = videoComposition
        }
        // Puts the movie header first, so uploads and previews can start before the whole file has arrived.
        session.shouldOptimizeForNetworkUse = true
        do {
            try await session.export(to: output, as: .mp4)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw RecordingError.isOutOfSpace(error) ? RecordingError.insufficientStorage : .exportFailed(error.localizedDescription)
        }
    }

    /// Copies the part of `movie` inside `range` to `output` without re-encoding (trimming, PLAN §7.4).
    @concurrent
    static func trim(_ movie: URL, range: CMTimeRange, to output: URL) async throws {
        try await export(AVURLAsset(url: movie), preset: AVAssetExportPresetPassthrough, to: output, timeRange: range)
    }
}
