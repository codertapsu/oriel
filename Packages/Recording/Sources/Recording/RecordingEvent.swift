/// A callback from ScreenCaptureKit, forwarded from its queue to the session on the main actor, in order.
nonisolated enum RecordingEvent: Sendable {
    /// Segment `index`'s output started writing.
    case segmentStarted(Int)
    /// Segment `index`'s file is complete.
    case segmentFinished(Int)
    /// Segment `index`'s output failed.
    case segmentFailed(Int, any Error)
    /// The stream stopped by itself: the user, the system, a full disk or a lost display ended it.
    case streamStopped(any Error)
}
