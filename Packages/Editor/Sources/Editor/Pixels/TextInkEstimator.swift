/// The two colours of a line of text in a screenshot: the background it sits on (the most common colour on the box's
/// edge) and its ink (the pixels that differ most from that background, which anti-aliasing leaves only at the
/// centre of each stroke). Simplify draws its bar in the ink colour. Pure.
nonisolated enum TextInkEstimator {
    /// Pixels closer than this to the background are background or the fringe of a glyph.
    static let inkThreshold = 48

    static func colors(in pixels: PixelImage) -> (background: PixelColor, ink: PixelColor)? {
        let bounds = PixelRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
        guard let background = ColorStatistics.dominant(ColorStatistics.ring(of: bounds, thickness: 1, in: pixels)) else { return nil }
        var ink: [(distance: Int, color: PixelColor)] = []
        for y in 0 ..< pixels.height {
            for x in 0 ..< pixels.width {
                let color = pixels[x, y]
                let distance = color.distance(to: background)
                if distance >= inkThreshold {
                    ink.append((distance, color))
                }
            }
        }
        guard !ink.isEmpty else { return (background, background) }
        // The strongest fifth: the cores of the strokes, not their blended edges.
        let strongest = ink.sorted { $0.distance > $1.distance }.prefix(max(1, ink.count / 5))
        let count = strongest.count
        let sums = strongest.reduce((0, 0, 0)) { ($0.0 + Int($1.color.red), $0.1 + Int($1.color.green), $0.2 + Int($1.color.blue)) }
        return (background, PixelColor(red: UInt8(sums.0 / count), green: UInt8(sums.1 / count), blue: UInt8(sums.2 / count)))
    }
}
