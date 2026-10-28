import Foundation
import ImageIO
@testable import Recording
import Testing
import UniformTypeIdentifiers

struct GIFExporterTests {
    private struct GIFInfo {
        let frameCount: Int
        let width: Int
        let height: Int
        let loopCount: Int?
        let totalDelay: Double
    }

    private func inspect(_ url: URL) throws -> GIFInfo {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.gif.identifier)
        let count = CGImageSourceGetCount(source)
        let first = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let file = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let gif = file?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        var total = 0.0
        for index in 0 ..< count {
            let frame = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let frameGIF = frame?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            total += (frameGIF?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0
        }
        return GIFInfo(
            frameCount: count,
            width: first.width,
            height: first.height,
            loopCount: gif?[kCGImagePropertyGIFLoopCount] as? Int,
            totalDelay: total
        )
    }

    @Test func samplesTheMovieAtTheFrameRateAndLimitsTheWidth() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await TestMovie.write(to: movie, width: 1280, height: 720, duration: 2.0)
        let gif = folder.file("movie.gif")

        let written = try await GIFExporter.export(movie, to: gif, options: GIFExportOptions(frameRate: 10, maxWidth: 800))

        let info = try inspect(gif)
        #expect(written == 20)
        #expect(info.frameCount == 20)
        #expect(info.width == 800)
        #expect(info.height == 450)
        #expect(info.loopCount == 0)
        #expect(abs(info.totalDelay - 2.0) < 0.05)
    }

    @Test func neverMakesANarrowMovieWider() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await TestMovie.write(to: movie, width: 320, height: 180, duration: 1.0)
        let gif = folder.file("movie.gif")

        try await GIFExporter.export(movie, to: gif, options: GIFExportOptions(frameRate: 15, maxWidth: 800))

        let info = try inspect(gif)
        #expect(info.frameCount == 15)
        #expect(info.width == 320)
        #expect(info.height == 180)
    }

    @Test func spreadsCentisecondRoundingAtTwelveFramesPerSecond() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await TestMovie.write(to: movie, width: 640, height: 360, duration: 1.5)
        let gif = folder.file("movie.gif")

        try await GIFExporter.export(movie, to: gif, options: GIFExportOptions(frameRate: 12, maxWidth: 480))

        let info = try inspect(gif)
        #expect(info.frameCount == 18)
        #expect(info.width == 480)
        #expect(info.height == 270)
        #expect(abs(info.totalDelay - 1.5) < 0.02)
    }

    @Test func keepsTheLengthOfAMovieWithLongStills() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        // A screen that changes twice in two seconds, as ScreenCaptureKit records it.
        let movie = folder.file("still.mp4")
        try await TestMovie.write(to: movie, width: 640, height: 400, frameTimes: [0, 1.5], duration: 2.0)
        let gif = folder.file("still.gif")

        try await GIFExporter.export(movie, to: gif, options: GIFExportOptions(frameRate: 10, maxWidth: 800))

        let info = try inspect(gif)
        #expect(info.frameCount == 20)
        #expect(info.width == 640)
        #expect(abs(info.totalDelay - 2.0) < 0.05)
    }

    @Test func clampsTheFrameRateToTenToFifteen() {
        #expect(GIFExportOptions(frameRate: 4, maxWidth: 800).frameRate == 10)
        #expect(GIFExportOptions(frameRate: 60, maxWidth: 800).frameRate == 15)
        #expect(GIFExportOptions(frameRate: 12, maxWidth: 2).maxWidth == GIFExportOptions.minimumWidth)
    }
}
