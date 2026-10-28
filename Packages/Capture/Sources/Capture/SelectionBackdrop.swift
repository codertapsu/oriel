import CoreGraphics

/// What one display's selection overlay shows under its chrome (PLAN §7.2, item 2): the display as it was when the
/// capture began, or nothing, so the live screen shows through (Settings → Capture → Freeze the screen while
/// selecting, off: for video).
nonisolated struct SelectionBackdrop: Sendable {
    let display: DisplayFrame
    /// The frozen picture; nil while the screen stays live.
    let image: CGImage?

    var id: CGDirectDisplayID {
        display.id
    }
}
