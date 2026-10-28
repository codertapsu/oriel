import CoreGraphics
import OrielCore

/// Which display a selection belongs to, which pixels it covers, and how all displays fit into one image
/// (PLAN §7.2, item 5). Pure, and tested with synthetic layouts: negative origins and mixed 1× and 2× scales.
nonisolated enum CaptureGeometry {
    /// Where each display goes in one image of all of them (`CaptureMode.allDisplays`).
    struct Composite: Sendable, Equatable {
        /// The union of the display frames, in global points.
        let bounds: CGRect
        /// The highest scale among the displays; lower-scale displays are scaled up to it.
        let scale: CGFloat
        let pixelSize: CGSize
        /// One rect per display, in the composite's pixels with a top-left origin.
        let placements: [CGRect]
    }

    /// The display that shows most of `rect`, or nil when `rect` is on none of them.
    static func display(for rect: CGRect, among displays: [DisplayFrame]) -> DisplayFrame? {
        guard let index = ScreenGeometry.bestDisplay(for: rect, among: displays.map(\.frame)) else { return nil }
        let display = displays[index]
        return display.frame.intersects(rect) ? display : nil
    }

    /// The display under `point`. Frames are half-open, so a point on the edge between two displays belongs to the
    /// one it starts.
    static func display(containing point: CGPoint, among displays: [DisplayFrame]) -> DisplayFrame? {
        displays.first { $0.frame.contains(point) }
    }

    /// `rect` (global points) clipped to `display`, in the pixels of that display's image. Zero when outside.
    static func pixelRect(for rect: CGRect, on display: DisplayFrame) -> CGRect {
        ScreenGeometry.pixelRect(for: rect, displayBounds: display.frame, scale: display.scale)
    }

    /// The composite of `displays` at the highest scale, or nil when there are none.
    static func composite(of displays: [DisplayFrame]) -> Composite? {
        guard let first = displays.first else { return nil }
        let bounds = displays.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        let scale = displays.map(\.scale).max() ?? 1
        let placements = displays.map { display in
            CGRect(
                x: ((display.frame.minX - bounds.minX) * scale).rounded(),
                y: ((display.frame.minY - bounds.minY) * scale).rounded(),
                width: (display.frame.width * scale).rounded(),
                height: (display.frame.height * scale).rounded()
            )
        }
        let size = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        return Composite(bounds: bounds, scale: scale, pixelSize: size, placements: placements)
    }

    /// `value` (global points) moved to the nearest pixel boundary of a display that starts at `origin`.
    static func align(_ value: CGFloat, origin: CGFloat, scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return value }
        return origin + ((value - origin) * scale).rounded() / scale
    }

    /// `rect` with every edge on the pixel grid of the display at `bounds`.
    static func align(_ rect: CGRect, in bounds: CGRect, scale: CGFloat) -> CGRect {
        let minX = align(rect.minX, origin: bounds.minX, scale: scale)
        let minY = align(rect.minY, origin: bounds.minY, scale: scale)
        let maxX = align(rect.maxX, origin: bounds.minX, scale: scale)
        let maxY = align(rect.maxY, origin: bounds.minY, scale: scale)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// `rect` shifted (not shrunk) so it lies inside `bounds`; shrunk only when it is larger than `bounds`.
    static func shiftInside(_ rect: CGRect, bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// `point` clamped into `bounds` (inclusive of the far edges, so a drag can reach the last pixel).
    static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    /// The largest rect with `size`'s aspect ratio that fits in `bounds`, centred.
    static func aspectFit(_ size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return bounds }
        let factor = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * factor, height: size.height * factor)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }
}
