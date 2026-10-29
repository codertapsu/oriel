/// One display's still picture, 8 bits per channel, scanned for edges. An edge is the boundary between two neighbouring
/// pixels whose colors differ by more than the tolerance in red, green or blue. Comparing neighbours, rather than
/// comparing with the pixel under the pointer, means the gentle steps of a gradient are not edges while an element's
/// border is, and noise below the tolerance is ignored.
///
/// Boundaries are numbered like the gaps between pixels: boundary 0 is the display's left (or top) edge, boundary
/// `width` its right edge, and boundary `b` lies between pixels `b − 1` and `b`.
nonisolated struct EdgeMap: Sendable {
    let width: Int
    let height: Int
    /// Row by row from the top; red in the low byte, then green and blue, as RGBA bytes read on a little-endian Mac.
    private let pixels: [UInt32]

    init(width: Int, height: Int, pixels: [UInt32]) {
        precondition(pixels.count == width * height, "an edge map needs one value per pixel")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// A pixel value from 0…255 channels.
    static func pixel(red: Int, green: Int, blue: Int) -> UInt32 {
        UInt32(red & 0xFF) | UInt32(green & 0xFF) << 8 | UInt32(blue & 0xFF) << 16 | 0xFF00_0000
    }

    func pixel(x: Int, y: Int) -> UInt32 {
        pixels[y * width + x]
    }

    /// Whether two pixel values differ by more than `tolerance` (0…255) in any color channel.
    @inline(__always)
    static func differs(_ first: UInt32, _ second: UInt32, tolerance: Int) -> Bool {
        guard first != second else { return false }
        let red = abs(Int(first & 0xFF) - Int(second & 0xFF))
        let green = abs(Int(first >> 8 & 0xFF) - Int(second >> 8 & 0xFF))
        let blue = abs(Int(first >> 16 & 0xFF) - Int(second >> 16 & 0xFF))
        return max(red, green, blue) > tolerance
    }

    /// The boundaries left and right of pixel (`column`, `row`) where the colors change: the span of the row that
    /// holds the pixel, `start ..< end`, reaching the display's edge where nothing changes.
    func horizontalSpan(row: Int, column: Int, tolerance: Int) -> (start: Int, end: Int) {
        pixels.withUnsafeBufferPointer { buffer in
            let base = row * width
            var start = column
            while start > 0, !Self.differs(buffer[base + start - 1], buffer[base + start], tolerance: tolerance) {
                start -= 1
            }
            var end = column + 1
            while end < width, !Self.differs(buffer[base + end - 1], buffer[base + end], tolerance: tolerance) {
                end += 1
            }
            return (start, end)
        }
    }

    /// The same, up and down the column.
    func verticalSpan(column: Int, row: Int, tolerance: Int) -> (start: Int, end: Int) {
        pixels.withUnsafeBufferPointer { buffer in
            var start = row
            while start > 0, !Self.differs(buffer[(start - 1) * width + column], buffer[start * width + column], tolerance: tolerance) {
                start -= 1
            }
            var end = row + 1
            while end < height, !Self.differs(buffer[(end - 1) * width + column], buffer[end * width + column], tolerance: tolerance) {
                end += 1
            }
            return (start, end)
        }
    }

    /// The column boundary on `row` nearest to `column`, within `radius` pixels, where the colors change; for snapping.
    func nearestColumnEdge(row: Int, near column: Int, within radius: Int, tolerance: Int) -> Int? {
        guard (0 ..< height).contains(row), let range = Self.innerBoundaries(around: column, within: radius, count: width) else {
            return nil
        }
        let base = row * width
        return nearest(to: column, in: range) { boundary in
            Self.differs(pixels[base + boundary - 1], pixels[base + boundary], tolerance: tolerance)
        }
    }

    /// The row boundary on `column` nearest to `row`, within `radius` pixels, where the colors change.
    func nearestRowEdge(column: Int, near row: Int, within radius: Int, tolerance: Int) -> Int? {
        guard (0 ..< width).contains(column), let range = Self.innerBoundaries(around: row, within: radius, count: height) else {
            return nil
        }
        return nearest(to: row, in: range) { boundary in
            Self.differs(pixels[(boundary - 1) * width + column], pixels[boundary * width + column], tolerance: tolerance)
        }
    }

    /// The boundaries between pixels (1 … count − 1) within `radius` of `position`; nil when there are none, as when
    /// the position lies beyond a picture smaller than its display.
    private static func innerBoundaries(around position: Int, within radius: Int, count: Int) -> ClosedRange<Int>? {
        let low = max(1, position - radius)
        let high = min(count - 1, position + radius)
        return low <= high ? low ... high : nil
    }

    /// The smallest rectangle inside `rect` that holds every edge in it: what was drawn around an element, shrunk to
    /// fit the element. Nil when nothing in `rect` changes color, so there is nothing to fit.
    func contentBounds(in rect: PixelRect, tolerance: Int) -> PixelRect? {
        let area = rect.clipped(width: width, height: height)
        guard !area.isEmpty else { return nil }
        var bounds: PixelRect?
        func include(_ minX: Int, _ minY: Int, _ maxX: Int, _ maxY: Int) {
            guard let current = bounds else {
                bounds = PixelRect(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
                return
            }
            bounds = PixelRect(
                minX: min(current.minX, minX),
                minY: min(current.minY, minY),
                maxX: max(current.maxX, maxX),
                maxY: max(current.maxY, maxY)
            )
        }
        pixels.withUnsafeBufferPointer { buffer in
            for row in area.minY ..< area.maxY {
                let base = row * width
                for column in area.minX ..< area.maxX {
                    let here = buffer[base + column]
                    // A change from the left neighbour puts a boundary at this column, in this row.
                    if column > area.minX, Self.differs(buffer[base + column - 1], here, tolerance: tolerance) {
                        include(column, row, column, row + 1)
                    }
                    // A change from the pixel above puts a boundary at this row, in this column.
                    if row > area.minY, Self.differs(buffer[base - width + column], here, tolerance: tolerance) {
                        include(column, row, column + 1, row)
                    }
                }
            }
        }
        guard let bounds, !bounds.isEmpty else { return nil }
        return bounds
    }

    /// The value in `range` closest to `target` that passes `test`.
    private func nearest(to target: Int, in range: ClosedRange<Int>, where test: (Int) -> Bool) -> Int? {
        var best: Int?
        for value in range where test(value) {
            if best.map({ abs(value - target) < abs($0 - target) }) ?? true {
                best = value
            }
        }
        return best
    }
}
