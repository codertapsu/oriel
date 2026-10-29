/// Fills a hole in an image with the background estimated from the pixels around it (PLAN §17, Smart Move and
/// Simplify): what is left where a lifted object or an erased line of text was.
///
/// Each side of the hole is sampled on a thin ring just outside it (the median across the ring, so a stray
/// anti-aliased pixel does not streak, then smoothed along the side). Every hole pixel blends a horizontal
/// interpolation between the left and right samples of its row with a vertical one between the top and bottom
/// samples of its column, weighted towards the nearer sides. Flat backgrounds come back exactly and linear gradients
/// in either direction come back as gradients, which covers the flat panels of most app windows. Busy backgrounds
/// (photos, patterns) come back as a smooth blend.
nonisolated enum HoleFiller {
    /// How many pixels outside the hole are sampled on each side.
    static let defaultRing = 3

    /// Fills `hole` (a pixel rect inside `image`) in place. Sides of the hole at the image's edge have nothing to
    /// sample and are left out of the blend; a hole that covers the whole image is left as it is.
    static func fill(_ image: inout PixelImage, hole: PixelRect, ring: Int = defaultRing) {
        let hole = hole.clipped(width: image.width, height: image.height)
        guard !hole.isEmpty else { return }
        let ring = max(1, ring)
        let left = sideSamples(of: image, hole: hole, ring: ring, side: .left)
        let right = sideSamples(of: image, hole: hole, ring: ring, side: .right)
        let top = sideSamples(of: image, hole: hole, ring: ring, side: .top)
        let bottom = sideSamples(of: image, hole: hole, ring: ring, side: .bottom)
        guard left != nil || right != nil || top != nil || bottom != nil else { return }
        // Where each side's samples sit, as a coordinate: the middle of its ring.
        let leftAt = Double(hole.x) - Double(left?.depth ?? ring) / 2 - 0.5
        let rightAt = Double(hole.maxX) + Double(right?.depth ?? ring) / 2 - 0.5
        let topAt = Double(hole.y) - Double(top?.depth ?? ring) / 2 - 0.5
        let bottomAt = Double(hole.maxY) + Double(bottom?.depth ?? ring) / 2 - 0.5
        for y in hole.y ..< hole.maxY {
            let row = y - hole.y
            for x in hole.x ..< hole.maxX {
                let column = x - hole.x
                let horizontal = interpolate(left?.values[row], right?.values[row], at: Double(x), from: leftAt, to: rightAt)
                let vertical = interpolate(top?.values[column], bottom?.values[column], at: Double(y), from: topAt, to: bottomAt)
                // Nearer sides count more, so the fill meets its surroundings without a seam.
                let horizontalWeight = 1 / max(1, min(Double(x) - leftAt, rightAt - Double(x)))
                let verticalWeight = 1 / max(1, min(Double(y) - topAt, bottomAt - Double(y)))
                image[x, y] = blend(horizontal, horizontalWeight, vertical, verticalWeight)
            }
        }
    }

    // MARK: - Private

    private enum Side {
        case left, right, top, bottom
    }

    /// One value per row (left, right) or column (top, bottom) of the hole, and how many pixels deep the ring was.
    private struct Samples {
        let values: [SIMDColor]
        let depth: Int
    }

    private typealias SIMDColor = SIMD4<Double>

    private static func sideSamples(of image: PixelImage, hole: PixelRect, ring: Int, side: Side) -> Samples? {
        let depth: Int = switch side {
        case .left: min(ring, hole.x)
        case .right: min(ring, image.width - hole.maxX)
        case .top: min(ring, hole.y)
        case .bottom: min(ring, image.height - hole.maxY)
        }
        guard depth > 0 else { return nil }
        let count = side == .left || side == .right ? hole.height : hole.width
        var values: [SIMDColor] = []
        values.reserveCapacity(count)
        for index in 0 ..< count {
            var pixels: [PixelColor] = []
            pixels.reserveCapacity(depth)
            for step in 0 ..< depth {
                switch side {
                case .left: pixels.append(image[hole.x - 1 - step, hole.y + index])
                case .right: pixels.append(image[hole.maxX + step, hole.y + index])
                case .top: pixels.append(image[hole.x + index, hole.y - 1 - step])
                case .bottom: pixels.append(image[hole.x + index, hole.maxY + step])
                }
            }
            values.append(median(pixels))
        }
        return Samples(values: smoothed(values, radius: 2), depth: depth)
    }

    private static func median(_ pixels: [PixelColor]) -> SIMDColor {
        func middle(_ channel: [UInt8]) -> Double {
            let sorted = channel.sorted()
            return Double(sorted[sorted.count / 2])
        }
        return SIMDColor(middle(pixels.map(\.red)), middle(pixels.map(\.green)), middle(pixels.map(\.blue)), middle(pixels.map(\.alpha)))
    }

    /// A box filter along a side, narrower near the ends so it stays centred: linear runs stay exactly linear,
    /// noise evens out.
    private static func smoothed(_ values: [SIMDColor], radius: Int) -> [SIMDColor] {
        guard values.count > 2, radius > 0 else { return values }
        return values.indices.map { index in
            let reach = min(radius, index, values.count - 1 - index)
            let range = (index - reach) ... (index + reach)
            let sum = range.reduce(SIMDColor.zero) { $0 + values[$1] }
            return sum / Double(range.count)
        }
    }

    private static func interpolate(
        _ first: SIMDColor?,
        _ second: SIMDColor?,
        at position: Double,
        from start: Double,
        to end: Double
    ) -> SIMDColor? {
        switch (first, second) {
        case let (first?, second?):
            let fraction = min(max((position - start) / max(end - start, 1), 0), 1)
            return first + (second - first) * fraction
        case let (first?, nil):
            return first
        case let (nil, second?):
            return second
        case (nil, nil):
            return nil
        }
    }

    private static func blend(_ first: SIMDColor?, _ firstWeight: Double, _ second: SIMDColor?, _ secondWeight: Double) -> PixelColor {
        let color: SIMDColor = switch (first, second) {
        case let (first?, second?): (first * firstWeight + second * secondWeight) / (firstWeight + secondWeight)
        case let (first?, nil): first
        case let (nil, second?): second
        case (nil, nil): SIMDColor.zero
        }
        func channel(_ value: Double) -> UInt8 {
            UInt8(min(max(value.rounded(), 0), 255))
        }
        return PixelColor(red: channel(color.x), green: channel(color.y), blue: channel(color.z), alpha: channel(color.w))
    }
}
