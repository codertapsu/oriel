import AVFoundation

/// Joins segment files into one movie with `AVMutableComposition` and a passthrough export, so nothing is
/// re-encoded (PLAN §7.4, D8).
///
/// Tracks are matched by position: the video track of every segment goes into one composition track, the first
/// audio track (system audio, or the mix on macOS 26) into another, the second (the microphone on macOS 27) into a
/// third. Each segment's tracks keep their own time ranges, so audio and video stay in sync within a segment.
nonisolated enum SegmentJoiner {
    /// Appends `segments` in order and writes them to `output`, which must not exist yet. Segments without video or
    /// without duration are skipped. Returns the duration of the joined movie.
    @concurrent
    @discardableResult
    static func join(_ segments: [URL], into output: URL) async throws -> CMTime {
        let composition = AVMutableComposition()
        var cursor = CMTime.zero
        var videoTrack: AVMutableCompositionTrack?
        var audioTracks: [AVMutableCompositionTrack] = []
        for url in segments {
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let duration = try await asset.load(.duration)
            guard duration.isNumeric, duration > .zero,
                  let video = try await asset.loadTracks(withMediaType: .video).first
            else {
                continue
            }
            let window = CMTimeRange(start: .zero, duration: duration)
            if videoTrack == nil {
                videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                videoTrack?.preferredTransform = try await video.load(.preferredTransform)
            }
            if let videoTrack {
                try await insert(video, range: video.load(.timeRange), within: window, into: videoTrack, at: cursor)
            }
            for (position, audio) in try await asset.loadTracks(withMediaType: .audio).enumerated() {
                if position == audioTracks.count {
                    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    else { continue }
                    audioTracks.append(track)
                }
                guard audioTracks.indices.contains(position) else { continue }
                try await insert(audio, range: audio.load(.timeRange), within: window, into: audioTracks[position], at: cursor)
            }
            cursor = CMTimeAdd(cursor, duration)
        }
        guard cursor > .zero else { throw RecordingError.nothingRecorded }
        try await MovieExporter.export(
            composition,
            preset: AVAssetExportPresetPassthrough,
            to: output,
            timeRange: CMTimeRange(start: .zero, duration: cursor)
        )
        return cursor
    }

    private static func insert(
        _ track: AVAssetTrack,
        range: CMTimeRange,
        within window: CMTimeRange,
        into composition: AVMutableCompositionTrack,
        at cursor: CMTime
    ) throws {
        let clipped = range.intersection(window)
        guard clipped.duration > .zero else { return }
        try composition.insertTimeRange(clipped, of: track, at: cursor + clipped.start)
    }
}
