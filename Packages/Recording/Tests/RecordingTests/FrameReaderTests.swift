import CoreGraphics
import CoreMedia
import Foundation
import OrielCore
@testable import Recording
import Testing

struct FrameReaderTests {
    /// "Reads" a frame by naming its colour, so the test sees exactly which frame was read.
    private struct ColourNamingRecognizer: TextRecognizing {
        func recognize(_ image: CGImage, mode: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
            #expect(mode == .fast)
            // The strongest channel names the colour; solid colours bleed into each other a little in H.264.
            let colour = PatternMovie.colour(in: image, x: image.width / 2, y: image.height / 2)
            let channels = [(colour >> 16 & 0xFF, "red"), (colour >> 8 & 0xFF, "green"), (colour & 0xFF, "blue")]
            let name = channels.max { $0.0 < $1.0 }?.1 ?? "unknown"
            return [
                OCRBlock(id: 0, text: name, boundingBox: .zero, confidence: 1),
                OCRBlock(id: 1, text: "line 2", boundingBox: .zero, confidence: 1),
            ]
        }
    }

    private struct BlankRecognizer: TextRecognizing {
        func recognize(_: CGImage, mode _: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
            []
        }
    }

    /// Red for the first second, green for the second, blue for the third, as three frames.
    private func writeColours(to url: URL) async throws {
        try await PatternMovie.write(to: url, frameTimes: [0, 1, 2], duration: 3) { frame, _, _, _, _ in
            [0xFF0000, 0x00FF00, 0x0000FF][frame]
        }
    }

    @Test func readsTheFrameAtTheExactTime() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("colours.mp4")
        try await writeColours(to: movie)
        let recognizer = ColourNamingRecognizer()

        #expect(try await FrameReader.text(of: movie, at: 0.5, recognizer: recognizer) == "red\nline 2")
        #expect(try await FrameReader.text(of: movie, at: 0.99, recognizer: recognizer) == "red\nline 2")
        #expect(try await FrameReader.text(of: movie, at: 1.0, recognizer: recognizer) == "green\nline 2")
        #expect(try await FrameReader.text(of: movie, at: 2.5, recognizer: recognizer) == "blue\nline 2")
    }

    @Test func readsTheLastFrameAtTheEnd() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("colours.mp4")
        try await writeColours(to: movie)

        #expect(try await FrameReader.text(of: movie, at: 3, recognizer: ColourNamingRecognizer()).hasPrefix("blue"))
        #expect(try await FrameReader.text(of: movie, at: 60, recognizer: ColourNamingRecognizer()).hasPrefix("blue"))
    }

    @Test func readsAFullSizeFrame() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("big.mp4")
        try await PatternMovie.write(to: movie, width: 1280, height: 720, frameTimes: [0], duration: 1)

        let image = try await FrameReader.image(of: movie, at: 0.5)
        #expect(image.width == 1280 && image.height == 720)
    }

    @Test func returnsNothingForAFrameWithoutText() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("colours.mp4")
        try await writeColours(to: movie)

        #expect(try await FrameReader.text(of: movie, at: 1.5, recognizer: BlankRecognizer()).isEmpty)
    }

    @Test func describesAMovie() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("info.mp4")
        try await PatternMovie.write(to: movie, width: 640, height: 360, frameTimes: [0, 1 / 30, 2 / 30, 1], duration: 2, audioTracks: 1)

        let info = try await MovieInfo.load(movie)
        #expect(abs(info.duration - 2) < 0.05)
        #expect(info.size == CGSize(width: 640, height: 360))
        #expect(info.frameRate == 30)
        #expect(info.hasAudio)
        #expect(info.codec == .h264)
        #expect(info.orientation == .up)

        await #expect(throws: VideoEditorError.unreadable) {
            try await MovieInfo.load(folder.file("missing.mp4"))
        }
    }

    @Test func roundsFrameRatesAndReadsOrientations() {
        #expect(MovieInfo.frameRate(minimumFrameDuration: CMTime(value: 1, timescale: 31), nominalRate: 10) == 30)
        #expect(MovieInfo.frameRate(minimumFrameDuration: CMTime(value: 1, timescale: 1000), nominalRate: 10) == 120)
        #expect(MovieInfo.frameRate(minimumFrameDuration: .invalid, nominalRate: 0) == 30)
        #expect(MovieInfo.orientation(for: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)) == .right)
        #expect(MovieInfo.orientation(for: CGAffineTransform(rotationAngle: .pi)) == .down)
        #expect(MovieInfo.orientation(for: .identity) == .up)
    }
}
