/// The extras a recording actually uses: what settings asked for and the permissions allow.
nonisolated struct RecordingFeatures: Equatable, Sendable {
    var microphone = false
    var cameraBubble = false
    var clickRings = false
    var keystrokes = false
    /// Whether clicks are logged for Auto Zoom.
    var clickLog = false
}
