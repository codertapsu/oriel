import CoreGraphics
import OrielCore

/// One display as the ruler sees it: where it is, in global CoreGraphics points (top-left origin of the primary display,
/// y down), and how many pixels each point has. Everything the ruler measures is in global points, and this converts
/// to the display's pixel grid (top-left origin) and back.
nonisolated struct RulerDisplay: Hashable, Sendable, Identifiable {
    let id: CGDirectDisplayID
    let frame: CGRect
    let scale: CGFloat

    init(id: CGDirectDisplayID, frame: CGRect, scale: CGFloat) {
        self.id = id
        self.frame = frame
        self.scale = max(scale, 1)
    }

    /// A screen as AppKit gives it (Cocoa, bottom-left origin), flipped with the primary display's height.
    init(id: CGDirectDisplayID, cocoaFrame: CGRect, primaryHeight: CGFloat, scale: CGFloat) {
        self.init(id: id, frame: ScreenGeometry.cgRect(fromCocoa: cocoaFrame, primaryHeight: primaryHeight), scale: scale)
    }

    var pixelWidth: Int {
        Int((frame.width * scale).rounded())
    }

    var pixelHeight: Int {
        Int((frame.height * scale).rounded())
    }

    func contains(_ point: CGPoint) -> Bool {
        frame.contains(point)
    }

    /// `point` in the display's pixel coordinates, fractional.
    func pixelCoordinate(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - frame.minX) * scale, y: (point.y - frame.minY) * scale)
    }

    /// The pixel under `point`, clamped to the display.
    func pixel(at point: CGPoint) -> (x: Int, y: Int) {
        let coordinate = pixelCoordinate(point)
        let x = min(max(Int(coordinate.x.rounded(.down)), 0), max(pixelWidth - 1, 0))
        let y = min(max(Int(coordinate.y.rounded(.down)), 0), max(pixelHeight - 1, 0))
        return (x, y)
    }

    /// A column boundary (0 … pixelWidth) in global points.
    func globalX(column: Int) -> CGFloat {
        frame.minX + CGFloat(column) / scale
    }

    /// A row boundary (0 … pixelHeight) in global points.
    func globalY(row: Int) -> CGFloat {
        frame.minY + CGFloat(row) / scale
    }

    func globalRect(_ rect: PixelRect) -> CGRect {
        CGRect(
            x: globalX(column: rect.minX),
            y: globalY(row: rect.minY),
            width: CGFloat(rect.width) / scale,
            height: CGFloat(rect.height) / scale
        )
    }

    /// The point moved onto the nearest line of `unit`'s grid (whole points or whole pixels, counted from the
    /// display's top-left corner) and kept on the display.
    func snapped(_ point: CGPoint, to unit: RulerUnit) -> CGPoint {
        let step = unit.step(scale: scale)
        let x = frame.minX + ((point.x - frame.minX) / step).rounded() * step
        let y = frame.minY + ((point.y - frame.minY) / step).rounded() * step
        return clamped(CGPoint(x: x, y: y))
    }

    func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, frame.minX), frame.maxX), y: min(max(point.y, frame.minY), frame.maxY))
    }

    /// The display under `point`, if any.
    static func display(at point: CGPoint, among displays: [RulerDisplay]) -> RulerDisplay? {
        displays.first { $0.contains(point) }
    }
}
