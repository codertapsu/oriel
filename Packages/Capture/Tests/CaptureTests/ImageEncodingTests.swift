@testable import Capture
import CoreGraphics
import Foundation
import ImageIO
import Testing

struct ImageEncodingTests {
    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    @Test(arguments: CaptureImageFormat.allCases)
    func everyFormatRecordsTheScaleAsDPI(_ format: CaptureImageFormat) throws {
        let image = try TestImages.quadrants(width: 40, height: 30)
        let data = try #require(ImageEncoding.data(for: image, format: format, scale: 2))
        let properties = try properties(of: data)
        #expect((properties[kCGImagePropertyDPIWidth] as? Double) == 144)
        #expect((properties[kCGImagePropertyPixelWidth] as? Int) == 40)
    }

    @Test func hdrImagesBecomeHEIC() throws {
        let image = try TestImages.hdr(width: 64, height: 48)
        let data = try #require(ImageEncoding.hdrHEICData(for: image, scale: 2))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect((CGImageSourceGetType(source) as String?) == CaptureImageFormat.heic.type.identifier)
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 64 && decoded.height == 48)
    }

    @Test func thumbnailsShrinkButNeverGrow() throws {
        let large = try TestImages.solid(width: 400, height: 200, red: 0, green: 0, blue: 1)
        let thumbnail = try #require(ImageEncoding.thumbnail(of: large, maxPixels: 100))
        #expect(thumbnail.width == 100 && thumbnail.height == 50)
        let small = try #require(ImageEncoding.thumbnail(of: large, maxPixels: 1000))
        #expect(small.width == 400)
        #expect(ImageEncoding.thumbnailData(for: large, maxPixels: 100) != nil)
    }

    @Test func magnifierSamplesAroundThePointerTopDown() throws {
        let image = try TestImages.quadrants(width: 20, height: 20)
        #expect(try TestImages.hex(image, x: 2, y: 2) == "#00FF00")
        #expect(try TestImages.hex(image, x: 15, y: 3) == "#0000FF")
        #expect(try TestImages.hex(image, x: 10, y: 17) == "#FF0000")
        let patch = try #require(PixelPatch.sample(image, x: 0, y: 0, size: 15))
        #expect(patch.size == 15 && patch.pixels.count == 15 * 15 * 4)
        #expect(patch.pixels[3] == 0) // outside the image
        #expect(patch.hexColor == "#00FF00")
        let even = try #require(PixelPatch.sample(image, x: 5, y: 5, size: 4))
        #expect(even.size == 5)
    }
}
