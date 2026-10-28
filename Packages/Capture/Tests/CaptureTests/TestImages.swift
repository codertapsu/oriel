@testable import Capture
import CoreGraphics
import Foundation
import Testing

/// Synthetic images for the tests: solid fills, split images that reveal orientation mistakes, and HDR.
enum TestImages {
    /// `width`×`height` pixels; `fill` paints in Core Graphics' bottom-left coordinates.
    static func make(width: Int, height: Int, fill: (CGContext) -> Void) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        fill(context)
        return try #require(context.makeImage())
    }

    static func solid(width: Int, height: Int, red: CGFloat, green: CGFloat, blue: CGFloat) throws -> CGImage {
        try make(width: width, height: height) { context in
            context.setFillColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Green on the top half, red on the bottom half; blue in the right half of the top half.
    static func quadrants(width: Int, height: Int) throws -> CGImage {
        try make(width: width, height: height) { context in
            context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
            context.setFillColor(CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height - height / 2))
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: width / 2, y: height / 2, width: width - width / 2, height: height - height / 2))
        }
    }

    /// The colour of pixel (`x`, `y`) (top-left origin) as `#RRGGBB`.
    static func hex(_ image: CGImage, x: Int, y: Int) throws -> String {
        try #require(PixelPatch.sample(image, x: x, y: y, size: 1)).hexColor
    }

    /// A 16-bit float image in extended linear sRGB with values above 1, as ScreenCaptureKit's HDR output has.
    static func hdr(width: Int, height: Int) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.extendedLinearSRGB))
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGImageByteOrderInfo.order16Little.rawValue
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 16,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: info
        ))
        let bright = try #require(CGColor(colorSpace: space, components: [3, 2.5, 2, 1]))
        context.setFillColor(bright)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "oriel-capture-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
