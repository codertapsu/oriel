/// Where the recording coordinator is in its life cycle.
///
/// `idle → starting → recording ⇄ paused → finishing → idle`. A failed start goes straight back to `idle`.
public nonisolated enum RecordingState: Sendable, Equatable {
    /// Nothing is being recorded.
    case idle
    /// Permissions are being requested and the stream is being set up.
    case starting
    /// Frames are being written to the current segment file.
    case recording
    /// The stream runs, but no segment file is open.
    case paused
    /// Capture has stopped; the segments are being joined into the final file.
    case finishing
}
