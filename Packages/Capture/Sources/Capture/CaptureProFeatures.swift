import OrielCore

/// What only Oriel Pro unlocks in capture (PLAN §19). Area, window and screen captures, the timer, Capture Text, Quick
/// Access, pins and the recent history stay free.
public extension ProFeature {
    nonisolated static let instantCapture = ProFeature(
        id: "capture.instant",
        title: "Instant Capture",
        summary: "Annotate a capture where it is, without leaving the app you are in.",
        module: .capture
    )
    nonisolated static let scrollingCapture = ProFeature(
        id: "capture.scrolling",
        title: "Scrolling Capture",
        summary: "Capture a whole page or list as one tall image.",
        module: .capture
    )
    nonisolated static let stepCapture = ProFeature(
        id: "capture.steps",
        title: "Step Capture",
        summary: "Turn each capture into a numbered step and export a guide as one image, a PDF or Markdown.",
        module: .capture
    )
    nonisolated static let pinTools = ProFeature(
        id: "capture.pinTools",
        title: "Pin opacity, click-through and lock",
        summary: "Fade a pin, click through it to the app below, or lock it in place.",
        module: .capture
    )
    nonisolated static let captureHistory = ProFeature(
        id: "capture.history",
        title: "Full capture history",
        summary: "Keep every capture, not only the last 20, and find one by the text in it.",
        module: .capture
    )
    nonisolated static let cleanDesktop = ProFeature(
        id: "capture.cleanDesktop",
        title: "Clean desktop",
        summary: "Leave desktop icons and widgets out of your captures.",
        module: .capture
    )

    /// Capture's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let captureFeatures: [ProFeature] = [
        .instantCapture, .scrollingCapture, .stepCapture, .pinTools, .captureHistory, .cleanDesktop,
    ]
}
