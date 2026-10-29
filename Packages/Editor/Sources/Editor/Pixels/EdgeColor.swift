import CoreGraphics

/// The colour of an image's edges, which the background's inset is filled with so a screenshot whose content runs
/// to its edges still looks framed and balanced.
nonisolated enum EdgeColor {
    /// How many pixels in from each edge are read.
    static let band = 2

    /// The most common colour on the `band`-pixel ring just inside `pixelRect` (top-left origin) of `image`. Only
    /// the four strips are decoded, so even a 6K screenshot costs a few thousand pixels. Nil for an empty rect.
    static func estimate(_ image: CGImage, in pixelRect: PixelRect) -> RGBAColor? {
        let rect = pixelRect.clipped(width: image.width, height: image.height)
        guard !rect.isEmpty else { return nil }
        let thickness = min(band, rect.width, rect.height)
        let strips = [
            PixelRect(x: rect.x, y: rect.y, width: rect.width, height: thickness),
            PixelRect(x: rect.x, y: rect.maxY - thickness, width: rect.width, height: thickness),
            PixelRect(x: rect.x, y: rect.y, width: thickness, height: rect.height),
            PixelRect(x: rect.maxX - thickness, y: rect.y, width: thickness, height: rect.height),
        ]
        var pixels: [PixelColor] = []
        for strip in strips where !strip.isEmpty {
            guard let decoded = PixelImage(image, region: strip.cgRect) else { continue }
            for y in 0 ..< decoded.height {
                for x in 0 ..< decoded.width {
                    pixels.append(decoded[x, y])
                }
            }
        }
        return ColorStatistics.dominant(pixels)?.rgbaColor
    }
}
