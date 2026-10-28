import CoreGraphics

/// Colours for an overlay block, sampled from the capture (PLAN §7.7.6).
enum BackgroundSampler {
    /// The per-channel median of a `ring`-pixel band just outside `box` (image pixels, top-left), clipped to the
    /// image. When the band lies entirely outside the image, the band just inside the box's edge is used.
    static func background(around box: CGRect, in buffer: PixelBuffer, ring: Int = 2) -> RGBColor {
        let inner = PixelBounds(box, in: buffer)
        var histogram = Histogram()
        add(inner.expanded(by: ring, within: buffer), minus: inner, of: buffer, to: &histogram)
        if histogram.count == 0 {
            // The box reaches the image's edges all round: use the band just inside it instead.
            add(inner, minus: inner.expanded(by: -ring, within: buffer), of: buffer, to: &histogram)
        }
        return histogram.median ?? .white
    }

    /// Adds the pixels of `outer` that are not in `hole` (which lies inside it), visiting only those pixels.
    private static func add(_ outer: PixelBounds, minus hole: PixelBounds, of buffer: PixelBuffer, to histogram: inout Histogram) {
        for y in outer.rows {
            // Rows beside the hole contribute their left and right parts; rows above and below it are whole.
            let bands = hole.rows.contains(y) && !hole.columns.isEmpty
                ? [outer.minX ..< max(outer.minX, hole.minX), min(hole.maxX, outer.maxX) ..< outer.maxX]
                : [outer.columns]
            for band in bands {
                for x in band {
                    histogram.add(buffer.pixel(x: x, y: y))
                }
            }
        }
    }

    /// The colour of the text inside `box`: the median of the pixels that differ most from `background`. Nil for a
    /// box with no clearly different pixels.
    static func foreground(in box: CGRect, of buffer: PixelBuffer, background: RGBColor) -> RGBColor? {
        let bounds = PixelBounds(box, in: buffer)
        let area = bounds.columns.count * bounds.rows.count
        guard area > 0 else { return nil }
        let stride = max(1, Int((Double(area) / 20000).squareRoot().rounded(.up)))
        let base = (red: background.red * 255, green: background.green * 255, blue: background.blue * 255)
        var samples: [(pixel: (red: UInt8, green: UInt8, blue: UInt8), distance: Double)] = []
        var farthest = 0.0
        for y in Swift.stride(from: bounds.minY, to: bounds.maxY, by: stride) {
            for x in Swift.stride(from: bounds.minX, to: bounds.maxX, by: stride) {
                let pixel = buffer.pixel(x: x, y: y)
                let dr = Double(pixel.red) - base.red
                let dg = Double(pixel.green) - base.green
                let db = Double(pixel.blue) - base.blue
                let distance = (dr * dr + dg * dg + db * db).squareRoot()
                farthest = max(farthest, distance)
                samples.append((pixel, distance))
            }
        }
        // Below this, the box is (almost) a flat colour and there is no text colour to keep.
        guard farthest >= 60 else { return nil }
        var histogram = Histogram()
        for sample in samples where sample.distance >= farthest * 0.6 {
            histogram.add(sample.pixel)
        }
        return histogram.median
    }
}

/// A box in whole pixels, clipped to the image: `minX..<maxX` by `minY..<maxY`.
private struct PixelBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    init(_ box: CGRect, in buffer: PixelBuffer) {
        minX = min(buffer.width, max(0, Int(box.minX.rounded(.down))))
        minY = min(buffer.height, max(0, Int(box.minY.rounded(.down))))
        maxX = min(buffer.width, max(minX, Int(box.maxX.rounded(.up))))
        maxY = min(buffer.height, max(minY, Int(box.maxY.rounded(.up))))
    }

    private init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = max(minX, maxX)
        self.maxY = max(minY, maxY)
    }

    var columns: Range<Int> {
        minX ..< maxX
    }

    var rows: Range<Int> {
        minY ..< maxY
    }

    /// Grown (or, for a negative amount, shrunk) on every side, and clipped to the image.
    func expanded(by amount: Int, within buffer: PixelBuffer) -> PixelBounds {
        PixelBounds(
            minX: max(0, minX - amount), minY: max(0, minY - amount),
            maxX: min(buffer.width, maxX + amount), maxY: min(buffer.height, maxY + amount)
        )
    }
}

/// Per-channel 256-bin histograms, for medians in linear time.
private struct Histogram {
    private var red = [Int](repeating: 0, count: 256)
    private var green = [Int](repeating: 0, count: 256)
    private var blue = [Int](repeating: 0, count: 256)
    private(set) var count = 0

    mutating func add(_ pixel: (red: UInt8, green: UInt8, blue: UInt8)) {
        red[Int(pixel.red)] += 1
        green[Int(pixel.green)] += 1
        blue[Int(pixel.blue)] += 1
        count += 1
    }

    var median: RGBColor? {
        guard count > 0 else { return nil }
        return RGBColor(bytes: Self.median(red, count), Self.median(green, count), Self.median(blue, count))
    }

    private static func median(_ bins: [Int], _ count: Int) -> UInt8 {
        let half = (count + 1) / 2
        var seen = 0
        for (value, number) in bins.enumerated() {
            seen += number
            if seen >= half {
                return UInt8(value)
            }
        }
        return 255
    }
}
