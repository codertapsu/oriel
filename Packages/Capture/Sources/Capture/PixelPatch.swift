import CoreGraphics

/// A small square of the frozen image around the pointer, for the magnifier loupe (PLAN §7.2, item 4): drawn
/// 8× without interpolation, with a pixel grid and the centre pixel's colour.
nonisolated struct PixelPatch: Sendable {
    /// Pixels per side (odd, so there is a centre pixel).
    let size: Int
    /// RGBA, 8 bits per channel, sRGB, premultiplied, top row first. Outside the image the pixels are transparent.
    let pixels: [UInt8]
    let image: CGImage?

    /// The centre pixel as `#RRGGBB` in sRGB.
    var hexColor: String {
        let offset = ((size / 2) * size + size / 2) * 4
        guard pixels.count >= offset + 3 else { return "#000000" }
        return "#" + [pixels[offset], pixels[offset + 1], pixels[offset + 2]].map(Self.hex).joined()
    }

    /// The `size`×`size` pixels of `image` centred on pixel (`x`, `y`) (top-left origin).
    static func sample(_ image: CGImage, x: Int, y: Int, size: Int = 15) -> Self? {
        let size = max(1, size | 1)
        let radius = size / 2
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let made: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            context.interpolationQuality = .none
            // Bitmap contexts have a bottom-left origin and keep their top row first in memory, so image row
            // (y - radius) has to land on the context's top row.
            let rect = CGRect(
                x: CGFloat(radius - x),
                y: CGFloat(size - image.height + y - radius),
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            )
            context.draw(image, in: rect)
            return context.makeImage()
        }
        return Self(size: size, pixels: pixels, image: made)
    }

    private static func hex(_ value: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(value >> 4)], digits[Int(value & 0x0F)]])
    }
}
