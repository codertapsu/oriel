import AppKit

/// What the overlay windows report to the overlay controller. Every window reports to the same one, so it does not
/// matter which of them is key.
protocol OverlayEventHandling: AnyObject {
    func overlay(_ event: OverlayEvent)
    /// Returns whether the key was handled (unhandled keys are not passed on, so they do not beep).
    func overlayKeyDown(_ event: NSEvent) -> Bool
    func overlayKeyUp(_ event: NSEvent)
    /// The pointer for a location: crosshair, open or closed hand, a resize arrow, a pointing hand.
    func overlayCursor(at point: CGPoint) -> NSCursor
}
