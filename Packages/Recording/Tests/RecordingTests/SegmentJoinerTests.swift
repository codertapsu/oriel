import AVFoundation
import Foundation
@testable import Recording
import Testing

struct SegmentJoinerTests {
    private func writeSegments(_ durations: [Double], in folder: TemporaryFolder) async throws -> [URL] {
        var segments: [URL] = []
        for (index, duration) in durations.enumerated() {
            let url = folder.file(SegmentLedger.fileName(for: index))
            try await TestMovie.write(to: url, duration: duration)
            segments.append(url)
        }
        return segments
    }

    @Test func joinsSegmentsIntoOneMovieAsLongAsAllOfThem() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let segments = try await writeSegments([1.0, 1.5, 0.5], in: folder)
        let output = folder.file("joined.mp4")

        let reported = try await SegmentJoiner.join(segments, into: output)

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 3.0) <= 0.2)
        #expect(abs(reported.seconds - 3.0) <= 0.2)
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        #expect(try await asset.load(.isPlayable))
    }

    @Test func keepsTheFrameSizeBecauseNothingIsReencoded() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let segments = try await writeSegments([0.5, 0.5], in: folder)
        let output = folder.file("joined.mp4")

        try await SegmentJoiner.join(segments, into: output)

        let track = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(size == CGSize(width: 320, height: 180))
        let isH264 = try await track.load(.formatDescriptions).allSatisfy { $0.mediaSubType == .h264 }
        #expect(isH264)
    }

    @Test func joinsVariableFrameRateSegments() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        // Frames only when "the screen changes": a burst, a long still, another burst.
        let first = folder.file("segment-000.mp4")
        try await TestMovie.write(to: first, frameTimes: [0, 0.033, 0.066, 1.2, 1.25], duration: 2.0)
        let second = folder.file("segment-001.mp4")
        try await TestMovie.write(to: second, frameTimes: [0, 0.9], duration: 1.0)
        let output = folder.file("joined.mp4")

        try await SegmentJoiner.join([first, second], into: output)

        let duration = try await AVURLAsset(url: output).load(.duration).seconds
        #expect(abs(duration - 3.0) <= 0.2)
    }

    @Test func refusesToJoinNothing() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        await #expect(throws: RecordingError.nothingRecorded) {
            try await SegmentJoiner.join([], into: folder.file("joined.mp4"))
        }
    }
}
