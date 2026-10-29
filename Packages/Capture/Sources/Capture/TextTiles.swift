import CoreGraphics

/// How a large capture is read for history search: Vision scales big images down before reading them, which loses
/// the text of a tall scrolling capture, so one longer than `maxLength` pixels is read in overlapping tiles, each
/// line whole in at least one of them.
nonisolated enum TextTiles {
    static let maxLength = 4096
    static let overlap = 128

    /// Tiles covering a `width` × `height` image (pixels, top-left origin), split only along a side longer than
    /// `maxLength`.
    static func rects(width: Int, height: Int) -> [CGRect] {
        guard width > 0, height > 0 else { return [] }
        let columns = spans(width)
        return spans(height).flatMap { row in
            columns.map { column in CGRect(x: column.start, y: row.start, width: column.length, height: row.length) }
        }
    }

    private static func spans(_ total: Int) -> [(start: Int, length: Int)] {
        var spans: [(start: Int, length: Int)] = []
        var start = 0
        while true {
            let length = min(maxLength, total - start)
            spans.append((start, length))
            guard start + maxLength < total else { break }
            start += maxLength - overlap
        }
        return spans
    }
}
