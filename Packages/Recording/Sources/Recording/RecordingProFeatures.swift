import OrielCore

/// What only Oriel Pro unlocks in screen recording (PLAN §19). Recording an area, a window or a screen with sound,
/// trimming, and MP4 stay free.
public extension ProFeature {
    nonisolated static let videoEditor = ProFeature(
        id: "recording.videoEditor",
        title: "Video editor",
        summary: "Auto Zoom on your clicks, zooms you place, chapters and text copied from a frame.",
        module: .recording
    )
    nonisolated static let cameraBubble = ProFeature(
        id: "recording.camera",
        title: "Camera bubble",
        summary: "Show yourself in a bubble while you record, with the room behind you blurred or replaced.",
        module: .recording
    )
    nonisolated static let clickHighlights = ProFeature(
        id: "recording.clicks",
        title: "Clicks and keystrokes",
        summary: "Rings where you click, and the keys you press, in the recording.",
        module: .recording
    )
    nonisolated static let recordingExports = ProFeature(
        id: "recording.exports",
        title: "GIF and constant frame rate",
        summary: "Export a recording as a GIF, or as a constant-frame-rate copy for video editors.",
        module: .recording
    )

    /// Recording's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let recordingFeatures: [ProFeature] = [.videoEditor, .cameraBubble, .clickHighlights, .recordingExports]
}
