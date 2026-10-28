import CoreGraphics

/// Conversions between the two global coordinate systems (PLAN §7.2, item 5). Pure, so they are testable with
/// synthetic display layouts.
///
/// Cocoa (NSScreen, NSWindow) puts the origin at the bottom-left of the primary display with y going up.
/// CoreGraphics, ScreenCaptureKit, CGWindowList and Accessibility put it at the top-left of the primary
/// display with y going down. Both use points. Flipping is its own inverse.
public enum ScreenGeometry {
    public static func cgRect(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func cocoaRect(fromCG rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        cgRect(fromCocoa: rect, primaryHeight: primaryHeight)
    }

    public static func cgPoint(fromCocoa point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public static func cocoaPoint(fromCG point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        cgPoint(fromCocoa: point, primaryHeight: primaryHeight)
    }

    /// The pixels of a display image covered by `rect` (global points), clipped to the display. Partial
    /// pixels at the edges are included, so a selection never loses its last row.
    public static func pixelRect(for rect: CGRect, displayBounds: CGRect, scale: CGFloat) -> CGRect {
        let local = rect.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY)
            .intersection(CGRect(origin: .zero, size: displayBounds.size))
        guard !local.isNull, local.width > 0, local.height > 0 else { return .zero }
        let minX = (local.minX * scale).rounded(.down)
        let minY = (local.minY * scale).rounded(.down)
        let maxX = (local.maxX * scale).rounded(.up)
        let maxY = (local.maxY * scale).rounded(.up)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// A rect from two drag points, in whichever order they came.
    public static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    /// The display (of `displays`) that contains most of `rect`, or the first one when none does.
    public static func bestDisplay(for rect: CGRect, among displays: [CGRect]) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, display) in displays.enumerated() {
            let overlap = display.intersection(rect)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > (best?.area ?? -1) {
                best = (index, area)
            }
        }
        return best?.index
    }
}
