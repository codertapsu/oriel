import Foundation

/// One segment file: what the recording wrote between a start or resume and the next pause or stop.
nonisolated struct RecordingSegment: Sendable, Equatable {
    /// Where the segment's recording output is in its life cycle.
    enum Phase: Sendable, Equatable {
        /// The output was added; the system has not confirmed that it records.
        case pending
        /// The output reported that it started recording.
        case recording
        /// The output was removed (pause) or capture stopped; the file is being finalized.
        case finalizing
        /// The file is complete.
        case finished
        /// The output failed; its file is unusable or missing.
        case failed(String)

        /// Whether nothing more will happen to the file.
        var isSettled: Bool {
            switch self {
            case .finished, .failed: true
            case .pending, .recording, .finalizing: false
            }
        }
    }

    /// 0 for the first segment, then one more per resume.
    let index: Int
    let url: URL
    /// When the segment was opened.
    let openedAt: ContinuousClock.Instant
    /// When the segment was closed by a pause or stop; nil while it is open.
    var closedAt: ContinuousClock.Instant?
    var phase: Phase

    /// Whether frames still go into this segment.
    var isOpen: Bool {
        closedAt == nil
    }

    /// Wall-clock time the segment was (or has been) open.
    func duration(at now: ContinuousClock.Instant) -> Duration {
        (closedAt ?? now) - openedAt
    }
}
