import CoreGraphics

/// How the freeze-frame overlay ended.
nonisolated enum OverlayOutcome: Sendable, Equatable {
    case cancelled
    /// An area on one display, global points on the display's pixel grid.
    case area(CGRect, display: CGDirectDisplayID, intent: OverlayIntent)
    case window(WindowTarget, intent: OverlayIntent)
    case screen(CGDirectDisplayID, intent: OverlayIntent)
}
