import OrielCore

public extension FeatureGuide {
    /// Screen recording's page in the feature tour (PLAN §19).
    nonisolated static let screenRecording = FeatureGuide(
        id: ModuleID.recording.rawValue,
        title: "Screen Recording",
        symbol: "record.circle",
        summary: "Record an area, a window or a whole screen, with system audio and your microphone, and save it as a "
            + "movie.",
        highlights: [
            Highlight("Record anything", "An area, a window or a screen, with a small bar to pause and stop."),
            Highlight("Sound", "System audio and your microphone, in the same movie."),
            Highlight("Trim and share", "Trim the finished recording, copy it, or read the text in a frame."),
            Highlight(
                "Video editor",
                "Zoom in on clicks automatically, add chapters, and export MP4, QuickTime or GIF.",
                pro: .videoEditor
            ),
            Highlight("Camera bubble", "Your camera in a round bubble over the recording.", pro: .cameraBubble),
            Highlight(
                Sandbox.isActive ? "Click highlights" : "Clicks and keystrokes",
                Sandbox.isActive
                    ? "Rings show where you clicked."
                    : "Rings show where you clicked, and the keys you press appear on screen.",
                pro: .clickHighlights
            ),
            Highlight("Exports", "GIFs, and constant-frame-rate copies for video editors.", pro: .recordingExports),
        ],
        commandID: "recordArea",
        permissions: [.screenRecording, .microphone, .camera]
    )
}
