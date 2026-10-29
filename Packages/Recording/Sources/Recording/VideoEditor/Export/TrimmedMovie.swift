import AVFoundation

/// The kept part of a movie as a composition whose timeline starts at 0 (PLAN §17), so the exports' zooms and
/// chapters are timed from the start of what they write. Nothing is copied or decoded to make it.
nonisolated struct TrimmedMovie {
    let composition: AVMutableComposition
    let videoTrack: AVCompositionTrack
    /// Every sound track, in order: system audio and the microphone stay apart until the export mixes them.
    let audioTracks: [AVCompositionTrack]
    /// Seconds.
    let duration: Double

    /// `range` (seconds) of `asset`'s first video track and of all its sound tracks.
    static func make(_ asset: AVAsset, range: ClosedRange<Double>) async throws -> TrimmedMovie {
        let timeRange = CMTimeRange(
            start: CMTime(seconds: range.lowerBound, preferredTimescale: 60000),
            end: CMTime(seconds: range.upperBound, preferredTimescale: 60000)
        )
        let composition = AVMutableComposition()
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw VideoEditorError.noVideo
        }
        let window = try await timeRange.intersection(video.load(.timeRange))
        guard window.duration > .zero else { throw VideoEditorError.tooShort }
        try videoTrack.insertTimeRange(window, of: video, at: window.start - timeRange.start)
        videoTrack.preferredTransform = try await video.load(.preferredTransform)
        var audioTracks: [AVCompositionTrack] = []
        for audio in try await asset.loadTracks(withMediaType: .audio) {
            let audioWindow = try await timeRange.intersection(audio.load(.timeRange))
            guard audioWindow.duration > .zero,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else {
                continue
            }
            try track.insertTimeRange(audioWindow, of: audio, at: audioWindow.start - timeRange.start)
            audioTracks.append(track)
        }
        return TrimmedMovie(
            composition: composition,
            videoTrack: videoTrack,
            audioTracks: audioTracks,
            duration: timeRange.duration.seconds
        )
    }
}
