import Foundation

/// Pure bookkeeping for the segment files of one recording (PLAN §7.4). Pause closes segment N, resume opens N+1,
/// stop closes the last one; at the end the finished segments are joined in order.
///
/// It also measures the elapsed time the control bar shows: the wall-clock time segments were open, so pauses do
/// not count. The movie's real duration comes from the files.
nonisolated struct SegmentLedger: Sendable, Equatable {
    /// The folder the segment files are written to.
    let directory: URL
    private(set) var segments: [RecordingSegment] = []

    /// The segment frames currently go to, if any.
    var openSegment: RecordingSegment? {
        guard let last = segments.last, last.isOpen else { return nil }
        return last
    }

    /// Whether every segment's file is complete or has failed, so the segments can be joined.
    var isSettled: Bool {
        segments.allSatisfy(\.phase.isSettled)
    }

    /// The complete segment files, in recording order.
    var finishedURLs: [URL] {
        segments.filter { $0.phase == .finished }.map(\.url)
    }

    /// `segment-000.mp4`, `segment-001.mp4`, …
    static func fileName(for index: Int) -> String {
        "segment-" + String(format: "%03d", index) + ".mp4"
    }

    /// Opens the next segment and returns it, or returns nil when one is already open.
    mutating func beginSegment(at instant: ContinuousClock.Instant) -> RecordingSegment? {
        guard openSegment == nil else { return nil }
        let index = segments.count
        let url = directory.appending(path: Self.fileName(for: index), directoryHint: .notDirectory)
        let segment = RecordingSegment(index: index, url: url, openedAt: instant, closedAt: nil, phase: .pending)
        segments.append(segment)
        return segment
    }

    /// Closes the open segment (pause or stop) and returns it, or returns nil when none is open.
    @discardableResult
    mutating func endSegment(at instant: ContinuousClock.Instant) -> RecordingSegment? {
        guard let index = segments.indices.last, segments[index].isOpen else { return nil }
        segments[index].closedAt = max(instant, segments[index].openedAt)
        if !segments[index].phase.isSettled {
            segments[index].phase = .finalizing
        }
        return segments[index]
    }

    /// The segment's output confirmed that it records.
    mutating func markStarted(_ index: Int) {
        guard segments.indices.contains(index), segments[index].phase == .pending else { return }
        segments[index].phase = .recording
    }

    /// The segment's file is complete.
    mutating func markFinished(_ index: Int) {
        guard segments.indices.contains(index), !segments[index].phase.isSettled else { return }
        segments[index].phase = .finished
    }

    /// The segment's output failed; its file is not joined.
    mutating func markFailed(_ index: Int, reason: String) {
        guard segments.indices.contains(index), !segments[index].phase.isSettled else { return }
        segments[index].phase = .failed(reason)
    }

    /// Settles segments whose outputs never reported back (after a timeout): a segment whose file exists counts as
    /// finished, because joining checks every file anyway; the others failed.
    mutating func settleRemaining(fileExists: (URL) -> Bool) {
        for index in segments.indices where !segments[index].phase.isSettled {
            segments[index].phase = fileExists(segments[index].url) ? .finished : .failed("The output never finished.")
        }
    }

    /// How long the recording has run, pauses excluded.
    func elapsed(at now: ContinuousClock.Instant) -> Duration {
        segments.reduce(.zero) { $0 + $1.duration(at: now) }
    }
}
