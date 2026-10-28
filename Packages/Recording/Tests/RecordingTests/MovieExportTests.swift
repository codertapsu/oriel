import AVFoundation
import Foundation
@testable import Recording
import Testing

struct MovieExportTests {
    @Test func trimsWithoutReencoding() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await TestMovie.write(to: movie, duration: 3.0)
        let trimmed = folder.file("trimmed.mp4")
        let range = CMTimeRange(
            start: CMTime(seconds: 0.5, preferredTimescale: 600),
            end: CMTime(seconds: 2.0, preferredTimescale: 600)
        )

        try await MovieExporter.trim(movie, range: range, to: trimmed)

        let duration = try await AVURLAsset(url: trimmed).load(.duration).seconds
        #expect(abs(duration - 1.5) <= 0.2)
    }

    @Test func convertsAVariableFrameRateMovieToAConstantOne() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("vfr.mp4")
        try await TestMovie.write(to: movie, frameTimes: [0, 0.02, 0.5, 0.51, 1.4], duration: 2.0)
        let output = folder.file("cfr.mp4")

        try await ConstantFrameRateExporter.export(movie, to: output, frameRate: 30)

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 2.0) <= 0.2)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (rate, minimum) = try await track.load(.nominalFrameRate, .minFrameDuration)
        #expect(abs(Double(rate) - 30) < 1)
        #expect(abs(minimum.seconds - 1.0 / 30) < 0.002)
    }

    @Test func refusesToOverwriteAnExistingFile() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("movie.mp4")
        try await TestMovie.write(to: movie, duration: 1.0)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 0.5, preferredTimescale: 600))
        await #expect(throws: (any Error).self) {
            try await MovieExporter.trim(movie, range: range, to: movie)
        }
        #expect(try await AVURLAsset(url: movie).load(.isPlayable))
    }

    @Test func aTrimThatKeepsEverythingChangesNothing() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        #expect(FinishedRecordingPanel.trimRange(start: .invalid, end: .invalid, duration: duration) == nil)
        #expect(FinishedRecordingPanel.trimRange(start: .zero, end: duration, duration: duration) == nil)
        let start = CMTime(seconds: 2, preferredTimescale: 600)
        #expect(
            FinishedRecordingPanel.trimRange(start: start, end: .invalid, duration: duration)
                == CMTimeRange(start: start, end: duration)
        )
        #expect(FinishedRecordingPanel.trimRange(start: duration, end: start, duration: duration) == nil)
    }
}
