/// The growing output of a scrolling capture: rows are appended as frames arrive (PLAN §7.3, item 8), so the work is
/// incremental and memory holds only the result and the current frame.
nonisolated struct StitchCanvas: Sendable {
    let width: Int
    private(set) var height = 0
    private(set) var pixels: [UInt8] = []

    /// Appends rows `rows` of `frame`, which must be as wide as the canvas.
    mutating func append(rows: Range<Int>, of frame: PixelFrame) {
        let rows = rows.clamped(to: 0 ..< frame.height)
        guard frame.width == width, !rows.isEmpty else { return }
        pixels.append(contentsOf: frame.rows(rows))
        height += rows.count
    }

    func makeFrame() -> PixelFrame {
        PixelFrame(width: width, height: height, pixels: pixels)
    }
}
