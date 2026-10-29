/// Summaries of a set of pixels: the colour most of them share, and the average. Pure.
nonisolated enum ColorStatistics {
    /// The most common colour among `pixels` (shades within a few levels count as one), as the average of the
    /// pixels in that bucket. Nil for no pixels.
    static func dominant(_ pixels: [PixelColor]) -> PixelColor? {
        guard !pixels.isEmpty else { return nil }
        var buckets: [PixelColor: (count: Int, sum: SIMD4<Int>)] = [:]
        for pixel in pixels {
            let key = pixel.quantized(step: 12)
            var entry = buckets[key] ?? (0, .zero)
            entry.count += 1
            entry.sum &+= SIMD4(Int(pixel.red), Int(pixel.green), Int(pixel.blue), Int(pixel.alpha))
            buckets[key] = entry
        }
        guard let best = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let mean = best.sum / best.count
        return PixelColor(red: UInt8(mean.x), green: UInt8(mean.y), blue: UInt8(mean.z), alpha: UInt8(mean.w))
    }

    /// The share of `pixels` within `tolerance` of `color`, 0…1.
    static func share(of color: PixelColor, in pixels: [PixelColor], tolerance: Int = 12) -> Double {
        guard !pixels.isEmpty else { return 0 }
        return Double(pixels.count { $0.distance(to: color) <= tolerance }) / Double(pixels.count)
    }

    /// The pixels of the ring `thickness` pixels wide just inside `rect`'s edge (all of `image`'s pixels on that
    /// ring, clipped to the image).
    static func ring(of rect: PixelRect, thickness: Int, in image: PixelImage) -> [PixelColor] {
        let clipped = rect.clipped(width: image.width, height: image.height)
        guard !clipped.isEmpty else { return [] }
        var pixels: [PixelColor] = []
        let band = max(1, min(thickness, min(clipped.width, clipped.height) / 2))
        // Whole rows along the top and bottom, then only the band's columns of the rows between.
        let rows = Array(clipped.y ..< clipped.y + band) + Array(max(clipped.y + band, clipped.maxY - band) ..< clipped.maxY)
        for y in rows {
            for x in clipped.x ..< clipped.maxX {
                pixels.append(image[x, y])
            }
        }
        let columns = Array(clipped.x ..< clipped.x + band) + Array(max(clipped.x + band, clipped.maxX - band) ..< clipped.maxX)
        for y in clipped.y + band ..< max(clipped.y + band, clipped.maxY - band) {
            for x in columns {
                pixels.append(image[x, y])
            }
        }
        return pixels
    }
}
