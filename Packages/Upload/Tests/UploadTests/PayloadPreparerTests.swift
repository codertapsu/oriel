import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Upload

struct PayloadPreparerTests {
    private static func image(width: Int = 8, height: Int = 6) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test func aCaptureBecomesATemporaryPNGThatGoesAfterwards() throws {
        let payload = try PayloadPreparer.image(Self.image(), scale: 2, name: "Safari")
        #expect(payload.fileExtension == "png")
        #expect(payload.contentType == "image/png")
        #expect(payload.isImage)
        #expect(payload.name == "Safari")
        let attributes = try FileManager.default.attributesOfItem(atPath: payload.fileURL.path)
        #expect((attributes[.size] as? Int64) == payload.byteCount)
        let source = try #require(CGImageSourceCreateWithURL(payload.fileURL as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
        PayloadPreparer.cleanUp(payload)
        #expect(!FileManager.default.fileExists(atPath: payload.fileURL.deletingLastPathComponent().path))
    }

    @Test func aPhotoLosesItsLocationAndCameraButKeepsItsOrientation() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let photo = folder.url.appending(path: "IMG_0001.jpg")
        let destination = try #require(CGImageDestinationCreateWithURL(photo as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret place"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "iPhone"],
        ]
        try CGImageDestinationAddImage(destination, Self.image(), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let original = try #require(CGImageSourceCreateWithURL(photo as CFURL, nil))
        let before = try #require(CGImageSourceCopyPropertiesAtIndex(original, 0, nil) as? [CFString: Any])
        #expect(before[kCGImagePropertyGPSDictionary] != nil)

        let payload = try PayloadPreparer.file(at: photo, stripsMetadata: true)
        defer { PayloadPreparer.cleanUp(payload) }
        #expect(payload.fileURL != photo)
        #expect(payload.name == "IMG_0001")
        #expect(payload.contentType == "image/jpeg")
        let source = try #require(CGImageSourceCreateWithURL(payload.fileURL as CFURL, nil))
        let after = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(after[kCGImagePropertyGPSDictionary] == nil)
        let exif = after[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
        let tiff = after[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFModel] == nil)
        #expect((after[kCGImagePropertyOrientation] as? NSNumber)?.intValue == 6)
        #expect(CGImageSourceGetCount(source) == 1)
    }

    @Test func otherFilesGoAsTheyAre() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = try folder.file("Recording.mov", contents: Data("moov".utf8))
        let payload = try PayloadPreparer.file(at: movie, stripsMetadata: true)
        #expect(payload.fileURL == movie)
        #expect(!payload.ownsFile)
        #expect(payload.contentType == "video/quicktime")
        #expect(payload.byteCount == 4)
        PayloadPreparer.cleanUp(payload)
        #expect(FileManager.default.fileExists(atPath: movie.path))
        #expect(throws: UploadError.self) { try PayloadPreparer.file(at: folder.url, stripsMetadata: false) }
    }
}
