import CoreGraphics

/// What to record. The app gets regions and windows from Capture's selection UI and passes them in.
public nonisolated enum RecordingTarget: Sendable, Equatable {
    /// A whole display.
    case display(CGDirectDisplayID)
    /// Part of one display, in global CoreGraphics points (top-left origin). Clipped to the display.
    case region(CGRect, displayID: CGDirectDisplayID)
    /// The on-screen frame of a window when recording starts. The recorded area does not follow the window if it
    /// moves; recording the frame keeps Oriel's overlays, menus and popovers in the video, which a single-window
    /// capture would drop.
    case window(CGWindowID)
}
