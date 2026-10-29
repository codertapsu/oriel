import CoreGraphics

/// What Dimensions shows at the pointer: the nearest edge to the left, right, above and below, found along the
/// pointer's row and column, and the box they make, which is what ⌘C copies. Its sides sit exactly on the edges, on the
/// display's pixel grid.
nonisolated struct DimensionsMeasurement: Sendable, Equatable {
    let display: RulerDisplay
    /// The boundaries around the pointer, in pixels.
    let box: PixelRect
    /// The pointer, in the display's pixel coordinates.
    let pointer: CGPoint

    /// Scans `map` from the pixel under `point`.
    init(at point: CGPoint, on display: RulerDisplay, in map: EdgeMap, tolerance: Int) {
        let pixel = display.pixel(at: point)
        let column = min(pixel.x, map.width - 1)
        let row = min(pixel.y, map.height - 1)
        let across = map.horizontalSpan(row: row, column: column, tolerance: tolerance)
        let down = map.verticalSpan(column: column, row: row, tolerance: tolerance)
        self.display = display
        box = PixelRect(minX: across.start, minY: down.start, maxX: across.end, maxY: down.end)
        let coordinate = display.pixelCoordinate(point)
        pointer = CGPoint(
            x: min(max(coordinate.x, CGFloat(box.minX)), CGFloat(box.maxX)),
            y: min(max(coordinate.y, CGFloat(box.minY)), CGFloat(box.maxY))
        )
    }

    init(display: RulerDisplay, box: PixelRect, pointer: CGPoint) {
        self.display = display
        self.box = box
        self.pointer = pointer
    }

    /// The box in global points.
    var rect: CGRect {
        display.globalRect(box)
    }

    /// How far each edge is from the pointer, in points.
    var left: CGFloat {
        (pointer.x - CGFloat(box.minX)) / display.scale
    }

    var right: CGFloat {
        (CGFloat(box.maxX) - pointer.x) / display.scale
    }

    var up: CGFloat {
        (pointer.y - CGFloat(box.minY)) / display.scale
    }

    var down: CGFloat {
        (CGFloat(box.maxY) - pointer.y) / display.scale
    }

    /// `320 × 48 pt`.
    func text(unit: RulerUnit) -> String {
        RulerFormat.size(rect.size, unit: unit, scale: display.scale)
    }
}
