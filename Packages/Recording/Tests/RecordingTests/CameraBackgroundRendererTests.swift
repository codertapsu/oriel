import CoreImage
import CoreVideo
import Foundation
@testable import Recording
import Testing

/// The camera background effect on synthetic frames: no camera is opened.
struct CameraBackgroundRendererTests {
    /// A 640 × 360 BGRA frame: left half `left`, right half `right` (0xRRGGBB).
    private func frame(left: UInt32, right: UInt32) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 640, 360, kCVPixelFormatType_32BGRA, attributes, &created)
        let buffer = try #require(created)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let base = try #require(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0 ..< 360 {
            let line = base.advanced(by: row * bytesPerRow).bindMemory(to: UInt32.self, capacity: 640)
            for column in 0 ..< 640 {
                line[column] = 0xFF00_0000 | (column < 320 ? left : right)
            }
        }
        return buffer
    }

    private func render(_ image: CIImage, size: CGSize) throws -> CGImage {
        let context = CIContext(options: [.cacheIntermediates: false])
        return try #require(context.createCGImage(image, from: CGRect(origin: .zero, size: size)))
    }

    @Test func replacesTheBackgroundWhereNoPersonIs() throws {
        let renderer = CameraBackgroundRenderer(
            background: .replaced(red: 0, green: 0.5, blue: 1),
            outputSize: CGSize(width: 120, height: 120)
        )
        let picture = try #require(try renderer.render(frame(left: 0x808080, right: 0x808080), time: 0))

        #expect(picture.width == 120 && picture.height == 120)
        for (x, y) in [(10, 10), (60, 60), (110, 110)] {
            #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: x, y: y), 0x0080FF, tolerance: 12), "at \(x), \(y)")
        }
    }

    @Test func blursAWholeBackground() throws {
        let renderer = CameraBackgroundRenderer(background: .blurred, outputSize: CGSize(width: 90, height: 90))
        let picture = try #require(try renderer.render(frame(left: 0xFF0000, right: 0x0000FF), time: 0))

        // Mirrored, and blurred across the edge between the halves.
        let middle = PatternMovie.colour(in: picture, x: 45, y: 45)
        #expect(middle >> 16 & 0xFF > 40 && middle & 0xFF > 40)
        #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: 2, y: 45), 0x0000FF, tolerance: 60))
    }

    @Test func fillsTheBubbleMirrored() throws {
        let source = try CIImage(cvPixelBuffer: frame(left: 0xFF0000, right: 0x0000FF))
        let fitted = CameraBackgroundRenderer.fill(source, to: CGSize(width: 100, height: 100), mirrored: true)
        let picture = try render(fitted, size: CGSize(width: 100, height: 100))

        #expect(fitted.extent == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: 5, y: 50), 0x0000FF))
        #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: 95, y: 50), 0xFF0000))
    }

    @Test func keepsThePersonWhereTheMaskIsWhite() throws {
        let source = try CIImage(cvPixelBuffer: frame(left: 0xFF0000, right: 0xFF0000))
        // A mask at a lower resolution, white on its left half: the "person".
        let mask = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 128, height: 192))
            .composited(over: CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 256, height: 192)))
        let composite = CameraBackgroundRenderer.composite(source, mask: mask, background: .replaced(red: 0, green: 1, blue: 0))
        let picture = try render(composite, size: CGSize(width: 640, height: 360))

        #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: 100, y: 180), 0xFF0000))
        #expect(PatternMovie.isClose(PatternMovie.colour(in: picture, x: 540, y: 180), 0x00FF00))
    }

    @Test func stopsOnceTheGovernorDoes() throws {
        let renderer = CameraBackgroundRenderer(background: .blurred, outputSize: CGSize(width: 60, height: 60))
        renderer.observe(thermalState: .critical, lowPowerMode: false)
        #expect(try renderer.render(frame(left: 0, right: 0), time: 0) == nil)
        #expect(renderer.stopReason == "the Mac is running hot")
    }
}
