import CoreGraphics
import OrielCore

/// What the session asks the overlay to do after an event; the session itself only changes state.
nonisolated enum RulerEffect: Equatable, Sendable {
    case close
    case copy(String)
    case copyAndClose(String)
    /// Close, and ask for Screen Recording (System Settings, if macOS no longer asks).
    case requestScreenRecording
    /// Shrink a drawn box to the content inside it, off the main thread, then `pin(_:on:)` the result.
    case fit(PixelRect, displayID: CGDirectDisplayID, tolerance: Int)
    /// The edge tolerance changed; keep it for next time.
    case toleranceChanged(Int)
    /// A Pro feature while Oriel Pro is locked: close, and show what Pro adds (PLAN §19).
    case needsPro(ProFeature)
    case beep
}
