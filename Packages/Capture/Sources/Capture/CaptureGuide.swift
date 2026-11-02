import OrielCore

public extension FeatureGuide {
    /// Screenshots' page in the feature tour (PLAN §19).
    nonisolated static let screenshots = FeatureGuide(
        id: ModuleID.capture.rawValue,
        title: "Screenshots",
        symbol: "camera.viewfinder",
        summary: "Capture an area, a window or a whole screen, then copy, save, annotate, pin or translate it from the "
            + "thumbnail that appears in the corner.",
        highlights: [
            Highlight(
                "Area, window or screen",
                "The screen freezes while you choose, with a loupe for exact pixels and edges that snap to windows."
            ),
            Highlight(
                "Quick Access",
                "After each capture: copy, save, annotate, pin or read its text, or drag the thumbnail into any app."
            ),
            Highlight("Capture Text", "Drag over text anywhere on screen and Oriel copies it, read on this Mac."),
            Highlight(
                "Scrolling Capture",
                Sandbox.isActive
                    ? "Scroll a long page and Oriel stitches it into one tall image."
                    : "Oriel scrolls a long page and stitches it into one tall image.",
                pro: .scrollingCapture
            ),
            Highlight("Instant Capture", "Draw on a capture right where it is, without leaving the app you are in.", pro: .instantCapture),
            Highlight(
                "Step Capture",
                "Every capture becomes a numbered step; export the steps as one image, a PDF, Markdown or a web page.",
                pro: .stepCapture
            ),
            Highlight("Pin tools", "Lock a pin in place, let clicks pass through it, or fade it to trace over it.", pro: .pinTools),
            Highlight("Capture History", "Search every capture by the text in it. Without Pro, the latest 20 show.", pro: .captureHistory),
            Highlight("Clean desktop", "Captures show your wallpaper without the desktop's icons and widgets.", pro: .cleanDesktop),
        ],
        commandID: "captureArea",
        permissions: [.screenRecording]
    )
}
