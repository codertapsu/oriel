import AVFoundation
import Foundation
@testable import Recording
import Testing

struct RecordingStorageTests {
    private let startedAt = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func movesASingleSegmentIntoTheOutputFolder() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let output = folder.url.appending(path: "Recordings", directoryHint: .isDirectory)
        let storage = RecordingStorage(outputFolder: output)
        try storage.prepare()
        let scratch = try storage.makeScratchFolder()
        defer { storage.discard(scratch) }
        let segment = scratch.appending(path: SegmentLedger.fileName(for: 0))
        try await TestMovie.write(to: segment, duration: 1.0)

        let movie = try await storage.finalize([segment], startedAt: startedAt)

        #expect(movie.deletingLastPathComponent().standardizedFileURL == output.standardizedFileURL)
        #expect(movie.lastPathComponent == RecordingFileNamer.baseName(for: startedAt) + ".mp4")
        #expect(!FileManager.default.fileExists(atPath: segment.path))
        #expect(try await AVURLAsset(url: movie).load(.isPlayable))
    }

    @Test func joinsSeveralSegmentsAndDropsUnreadableOnes() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let storage = RecordingStorage(outputFolder: folder.url)
        let first = folder.file("segment-000.mp4")
        let broken = folder.file("segment-001.mp4")
        let last = folder.file("segment-002.mp4")
        try await TestMovie.write(to: first, duration: 1.0)
        try Data("not a movie".utf8).write(to: broken)
        try await TestMovie.write(to: last, duration: 0.5)

        let movie = try await storage.finalize([first, broken, folder.file("missing.mp4"), last], startedAt: startedAt)

        let duration = try await AVURLAsset(url: movie).load(.duration).seconds
        #expect(abs(duration - 1.5) <= 0.2)
    }

    @Test func reportsNothingRecordedWithoutAPlayableSegment() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let storage = RecordingStorage(outputFolder: folder.url)
        await #expect(throws: RecordingError.nothingRecorded) {
            try await storage.finalize([folder.file("missing.mp4")], startedAt: startedAt)
        }
    }

    @Test func salvagesSegmentsAsNumberedParts() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let output = folder.url.appending(path: "Out", directoryHint: .isDirectory)
        let storage = RecordingStorage(outputFolder: output)
        try storage.prepare()
        let first = folder.file("segment-000.mp4")
        let second = folder.file("segment-001.mp4")
        try await TestMovie.write(to: first, duration: 0.5)
        try await TestMovie.write(to: second, duration: 0.5)

        let parts = await storage.salvage([first, second], startedAt: startedAt)

        let base = RecordingFileNamer.baseName(for: startedAt)
        #expect(parts.map(\.lastPathComponent) == ["\(base) part 1.mp4", "\(base) part 2.mp4"])
    }
}
