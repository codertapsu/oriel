import AppKit

/// What the overlay windows hand their controller, with every position in global points.
protocol RulerEventHandling: AnyObject {
    func rulerMouseMoved(to point: CGPoint)
    func rulerMouseDown(at point: CGPoint, clickCount: Int)
    func rulerMouseDragged(to point: CGPoint, modifiers: NSEvent.ModifierFlags)
    func rulerMouseUp(at point: CGPoint)
    func rulerRightMouseDown(at point: CGPoint)
    /// Returns whether the key was the ruler's.
    func rulerKeyDown(_ event: NSEvent) -> Bool
    func rulerCursor() -> NSCursor
}
