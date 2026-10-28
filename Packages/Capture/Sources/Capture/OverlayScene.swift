import CoreGraphics

/// What one display's overlay window shows right now; the overlay controller computes it after every event. All
/// geometry is in global CoreGraphics points.
struct OverlayScene {
    var selection: CGRect?
    var showsHandles = false
    var highlight: CGRect?
    /// A filled, tinted highlight (window and screen mode) rather than a thin outline (hovering in area mode).
    var highlightIsStrong = false
    var crosshair: CGPoint?
    /// The W × H readout.
    var readout: String?
    var magnifier: PixelPatch?
    var magnifierCaption = ""
    var pointer: CGPoint?
    var showsToolbar = false
    var hint: String?
}
