import CoreGraphics

/// A box being drawn in Dimensions, which shrinks to the content inside it when the mouse is released.
nonisolated struct FitDrag: Sendable, Equatable {
    let display: RulerDisplay
    let start: CGPoint
    var end: CGPoint

    var rect: CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// The whole pixels the box covers, partial ones included.
    var pixelRect: PixelRect {
        let low = display.pixelCoordinate(CGPoint(x: rect.minX, y: rect.minY))
        let high = display.pixelCoordinate(CGPoint(x: rect.maxX, y: rect.maxY))
        return PixelRect(
            minX: Int(low.x.rounded(.down)),
            minY: Int(low.y.rounded(.down)),
            maxX: Int(high.x.rounded(.up)),
            maxY: Int(high.y.rounded(.up))
        ).clipped(width: display.pixelWidth, height: display.pixelHeight)
    }
}
