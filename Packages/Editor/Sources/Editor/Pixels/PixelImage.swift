import CoreGraphics
import Foundation

/// A bitmap the smart tools can read and write pixel by pixel: sRGB, 8-bit RGBA, premultiplied, top row first.
/// Pure value type, so the pixel algorithms are tested on synthetic images without drawing anything.
nonisolated struct PixelImage: Sendable, Equatable {
    let width: Int
    let height: Int
    private(set) var bytes: [UInt8]

    init(width: Int, height: Int, fill: PixelColor = PixelColor(red: 0, green: 0, blue: 0, alpha: 0)) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        var bytes = [UInt8](repeating: 0, count: self.width * self.height * 4)
        for offset in stride(from: 0, to: bytes.count, by: 4) {
            bytes[offset] = fill.red
            bytes[offset + 1] = fill.green
            bytes[offset + 2] = fill.blue
            bytes[offset + 3] = fill.alpha
        }
        self.bytes = bytes
    }

    /// `image`, or the part of it inside `region` (a pixel rect with a top-left origin, clipped to the image),
    /// redrawn as sRGB RGBA8. Nil when the region is empty or the pixels cannot be drawn.
    init?(_ image: CGImage, region: CGRect? = nil) {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = (region ?? bounds).integral.intersection(bounds)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return nil }
        let source = rect == bounds ? image : image.cropping(to: rect)
        guard let source, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = Int(rect.width), height = Int(rect.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    subscript(x: Int, y: Int) -> PixelColor {
        get {
            let offset = (y * width + x) * 4
            return PixelColor(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
        }
        set {
            let offset = (y * width + x) * 4
            bytes[offset] = newValue.red
            bytes[offset + 1] = newValue.green
            bytes[offset + 2] = newValue.blue
            bytes[offset + 3] = newValue.alpha
        }
    }

    func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    /// The pixels inside `rect` (clipped to the image), as an image of their own.
    func cropped(to rect: PixelRect) -> PixelImage {
        let clipped = rect.clipped(width: width, height: height)
        var result = PixelImage(width: clipped.width, height: clipped.height)
        for y in 0 ..< clipped.height {
            for x in 0 ..< clipped.width {
                result[x, y] = self[clipped.x + x, clipped.y + y]
            }
        }
        return result
    }

    /// The bitmap as a `CGImage` (sRGB, premultiplied alpha).
    func makeImage() -> CGImage? {
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}
