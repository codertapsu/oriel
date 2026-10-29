/// A rectangle of whole pixels on one display: columns `minX ..< maxX`, rows `minY ..< maxY`, top-left origin.
nonisolated struct PixelRect: Hashable, Sendable {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var width: Int {
        maxX - minX
    }

    var height: Int {
        maxY - minY
    }

    var isEmpty: Bool {
        width <= 0 || height <= 0
    }

    /// Clipped to `0 ..< width` and `0 ..< height`.
    func clipped(width: Int, height: Int) -> PixelRect {
        PixelRect(minX: max(0, minX), minY: max(0, minY), maxX: min(width, maxX), maxY: min(height, maxY))
    }
}
