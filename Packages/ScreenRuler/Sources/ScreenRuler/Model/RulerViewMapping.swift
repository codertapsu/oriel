import CoreGraphics
import OrielCore

/// Between global CoreGraphics points and the view of the display's overlay window (Cocoa: bottom-left origin, one
/// point per point). The flip goes through `ScreenGeometry` with the display's own bottom edge as the flip height,
/// which puts the window's origin at (0, 0).
nonisolated struct RulerViewMapping: Sendable, Equatable {
    let display: RulerDisplay

    func viewPoint(_ point: CGPoint) -> CGPoint {
        let flipped = ScreenGeometry.cocoaPoint(fromCG: point, primaryHeight: display.frame.maxY)
        return CGPoint(x: flipped.x - display.frame.minX, y: flipped.y)
    }

    func globalPoint(_ point: CGPoint) -> CGPoint {
        ScreenGeometry.cgPoint(fromCocoa: CGPoint(x: point.x + display.frame.minX, y: point.y), primaryHeight: display.frame.maxY)
    }

    func viewRect(_ rect: CGRect) -> CGRect {
        ScreenGeometry.cocoaRect(fromCG: rect, primaryHeight: display.frame.maxY).offsetBy(dx: -display.frame.minX, dy: 0)
    }

    /// A global x as the view's x.
    func viewX(_ x: CGFloat) -> CGFloat {
        x - display.frame.minX
    }

    /// A global y as the view's y.
    func viewY(_ y: CGFloat) -> CGFloat {
        display.frame.maxY - y
    }
}
