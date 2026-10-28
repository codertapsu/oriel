import CoreGraphics
import OrielCore

/// Converts between global CoreGraphics points (top-left origin) and the view coordinates of one display's overlay
/// window (Cocoa, bottom-left origin, one point per point). The flip goes through `ScreenGeometry` with the display's
/// own bottom edge as the flip height, which makes the window's origin (0, 0); pure, so it is unit-tested.
nonisolated struct OverlayGeometry: Sendable, Equatable {
    /// The display's frame in global CoreGraphics points.
    let displayFrame: CGRect
    /// Pixels per point of the display.
    let scale: CGFloat

    func viewPoint(_ point: CGPoint) -> CGPoint {
        let flipped = ScreenGeometry.cocoaPoint(fromCG: point, primaryHeight: displayFrame.maxY)
        return CGPoint(x: flipped.x - displayFrame.minX, y: flipped.y)
    }

    func globalPoint(_ point: CGPoint) -> CGPoint {
        ScreenGeometry.cgPoint(fromCocoa: CGPoint(x: point.x + displayFrame.minX, y: point.y), primaryHeight: displayFrame.maxY)
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        ScreenGeometry.cocoaRect(fromCG: rect, primaryHeight: displayFrame.maxY).offsetBy(dx: -displayFrame.minX, dy: 0)
    }

    /// The pixel of the display's image under `point` (top-left origin), clamped to the image.
    func pixel(at point: CGPoint) -> (x: Int, y: Int) {
        let maxX = Int((displayFrame.width * scale).rounded()) - 1
        let maxY = Int((displayFrame.height * scale).rounded()) - 1
        let x = Int(((point.x - displayFrame.minX) * scale).rounded(.down))
        let y = Int(((point.y - displayFrame.minY) * scale).rounded(.down))
        return (min(max(x, 0), max(maxX, 0)), min(max(y, 0), max(maxY, 0)))
    }
}
