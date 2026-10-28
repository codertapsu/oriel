import CoreGraphics
@testable import Editor
import Foundation

/// Synthetic images, generated in the test so no fixture can drift.
enum TestImages {
    /// An opaque sRGB image whose pixel colour `fill(x, y)` returns, with y counted from the top.
    static func make(width: Int, height: Int, fill: (Int, Int) -> RGBA8) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = fill(x, y)
                let offset = (y * width + x) * 4
                bytes[offset] = pixel.red
                bytes[offset + 1] = pixel.green
                bytes[offset + 2] = pixel.blue
                bytes[offset + 3] = pixel.alpha
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// One flat colour, drawn by Core Graphics (fast for large sizes).
    static func solid(width: Int, height: Int, color: CGColor = CGColor(gray: 0.5, alpha: 1)) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Left half grey-blue, right half sand: flat areas, so any change is easy to spot.
    static func halves(width: Int, height: Int) -> CGImage? {
        make(width: width, height: height) { x, _ in x < width / 2 ? RGBA8(red: 60, green: 90, blue: 140) : RGBA8(
            red: 220,
            green: 200,
            blue: 160
        ) }
    }

    /// Deterministic high-frequency noise, which blur visibly smooths.
    static func noise(width: Int, height: Int) -> CGImage? {
        make(width: width, height: height) { x, y in
            var hash = UInt32(truncatingIfNeeded: x &* 73_856_093 ^ y &* 19_349_663)
            hash ^= hash >> 13
            hash = hash &* 0x5BD1_E995
            hash ^= hash >> 15
            let value = UInt8(truncatingIfNeeded: hash)
            return RGBA8(red: value, green: value, blue: value)
        }
    }

    static func document(width: Int = 200, height: Int = 120, scale: CGFloat = 2) throws -> EditorDocument {
        guard let image = halves(width: width, height: height) else { throw TestFailure("could not make the base image") }
        return EditorDocument(base: ImageRef(image: image, scale: scale))
    }
}

/// One 8-bit RGBA pixel.
struct RGBA8: Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8 = 255

    /// The largest per-channel difference to `other`.
    func distance(to other: RGBA8) -> Int {
        max(
            abs(Int(red) - Int(other.red)),
            abs(Int(green) - Int(other.green)),
            abs(Int(blue) - Int(other.blue)),
            abs(Int(alpha) - Int(other.alpha))
        )
    }
}

/// An image redrawn into a known layout (sRGB, RGBA8, premultiplied), so tests can read pixels.
struct PixelBuffer {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) throws {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw TestFailure("no sRGB") }
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw TestFailure("could not read the pixels") }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// The pixel at column `x`, row `y` counted from the top.
    func pixel(_ x: Int, _ y: Int) -> RGBA8 {
        let offset = (y * width + x) * 4
        return RGBA8(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }

    /// The pixel under a point given in points, at `scale` pixels per point.
    func pixel(at point: CGPoint, scale: CGFloat) -> RGBA8 {
        pixel(min(width - 1, Int(point.x * scale)), min(height - 1, Int(point.y * scale)))
    }

    /// Mean luminance-ish value and variance over a pixel rect, to compare textures.
    func statistics(in rect: CGRect) -> (mean: Double, variance: Double) {
        var values: [Double] = []
        for y in Int(rect.minY) ..< Int(rect.maxY) {
            for x in Int(rect.minX) ..< Int(rect.maxX) {
                let pixel = pixel(x, y)
                values.append((Double(pixel.red) + Double(pixel.green) + Double(pixel.blue)) / 3)
            }
        }
        guard !values.isEmpty else { return (0, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        return (mean, values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count))
    }

    /// Whether every pixel equals `other`'s.
    func isIdentical(to other: PixelBuffer) -> Bool {
        width == other.width && height == other.height && bytes == other.bytes
    }

    /// This buffer averaged down by `factor` (box filter), to compare a 2× render with a 1× one.
    func downsampled(by factor: Int) -> [RGBA8] {
        var result: [RGBA8] = []
        for y in 0 ..< height / factor {
            for x in 0 ..< width / factor {
                var sums = [0, 0, 0, 0]
                for dy in 0 ..< factor {
                    for dx in 0 ..< factor {
                        let pixel = pixel(x * factor + dx, y * factor + dy)
                        sums[0] += Int(pixel.red)
                        sums[1] += Int(pixel.green)
                        sums[2] += Int(pixel.blue)
                        sums[3] += Int(pixel.alpha)
                    }
                }
                let count = factor * factor
                result.append(RGBA8(
                    red: UInt8(sums[0] / count), green: UInt8(sums[1] / count), blue: UInt8(sums[2] / count), alpha: UInt8(sums[3] / count)
                ))
            }
        }
        return result
    }

    var allPixels: [RGBA8] {
        (0 ..< height).flatMap { y in (0 ..< width).map { x in pixel(x, y) } }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
