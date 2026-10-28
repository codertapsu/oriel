import CoreGraphics
import Foundation

/// One frame of a scrolling capture: 8-bit RGBA pixels, top row first (PLAN §7.3). Pure value, so the stitcher can be
/// tested on synthetic frames and run off the main thread.
nonisolated struct PixelFrame: Sendable, Equatable {
    let width: Int
    let height: Int
    /// RGBA, 8 bits per channel, premultiplied alpha, `width * 4` bytes per row.
    let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4, "PixelFrame needs width × height × 4 bytes")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// `image` drawn into 8-bit RGBA in `colorSpace` (the display's, so nothing is converted twice).
    init?(image: CGImage, colorSpace: CGColorSpace) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, pixels: pixels)
    }

    /// Rows become columns, so horizontal scrolling can reuse the vertical algorithm.
    func transposed() -> Self {
        var output = [UInt8](repeating: 0, count: pixels.count)
        pixels.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { target in
                for row in 0 ..< height {
                    for column in 0 ..< width {
                        let from = (row * width + column) * 4
                        let to = (column * height + row) * 4
                        target[to] = source[from]
                        target[to + 1] = source[from + 1]
                        target[to + 2] = source[from + 2]
                        target[to + 3] = source[from + 3]
                    }
                }
            }
        }
        return Self(width: height, height: width, pixels: output)
    }

    /// Luma (BT.601 weights), one byte per pixel.
    func grayscale() -> [UInt8] {
        var gray = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeBufferPointer { source in
            gray.withUnsafeMutableBufferPointer { target in
                for index in 0 ..< width * height {
                    let red = UInt32(source[index * 4])
                    let green = UInt32(source[index * 4 + 1])
                    let blue = UInt32(source[index * 4 + 2])
                    target[index] = UInt8((77 * red + 150 * green + 29 * blue) >> 8)
                }
            }
        }
        return gray
    }

    /// The bytes of rows `rows`.
    func rows(_ rows: Range<Int>) -> ArraySlice<UInt8> {
        pixels[(rows.lowerBound * width * 4) ..< (rows.upperBound * width * 4)]
    }

    func makeImage(colorSpace: CGColorSpace) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
