import CoreGraphics

/// A mouse event or toolbar click on an overlay window, with its location in global CoreGraphics points.
enum OverlayEvent {
    case mouseMoved(CGPoint)
    case mouseDown(CGPoint, clickCount: Int)
    case mouseDragged(CGPoint)
    case mouseUp(CGPoint)
    case rightMouseDown
    case tool(OverlayTool)
}
