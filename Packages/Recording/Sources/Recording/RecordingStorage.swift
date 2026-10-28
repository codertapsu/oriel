import AVFoundation
import Foundation
import OrielCore

/// Where a recording's files live: the segments in a scratch folder on the output folder's volume, the finished
/// movie in the output folder (`AppPaths.recordings` unless settings name another).
nonisolated struct RecordingStorage: Sendable {
    /// Recording does not start with less free space than this on the output folder's volume.
    static let minimumFreeBytes: Int64 = 512 * 1024 * 1024

    let outputFolder: URL

    /// Creates the output folder if needed and checks that its volume has room for a recording.
    func prepare() throws {
        try AppPaths.ensureDirectory(outputFolder)
        let values = try outputFolder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values.volumeAvailableCapacityForImportantUsage, free < Self.minimumFreeBytes {
            throw RecordingError.insufficientStorage
        }
    }

    /// A new, empty folder for one recording's segments (each call makes a unique one). It is on the output
    /// folder's volume, so a single segment becomes the final movie by a rename rather than a copy, and it sits in
    /// the system's temporary items, which macOS cleans up if Oriel quits before `discard(_:)`.
    func makeScratchFolder() throws -> URL {
        try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: outputFolder, create: true)
    }

    /// Turns the segments into the finished movie: a single segment is moved, several are joined (PLAN §7.4).
    /// Unreadable or empty segments are dropped. Returns the movie's URL.
    @concurrent
    func finalize(_ segments: [URL], startedAt date: Date) async throws -> URL {
        var playable: [URL] = []
        for url in segments where await Self.hasFrames(url) {
            playable.append(url)
        }
        guard !playable.isEmpty else { throw RecordingError.nothingRecorded }
        let destination = RecordingFileNamer.uniqueURL(
            in: outputFolder,
            baseName: RecordingFileNamer.baseName(for: date),
            pathExtension: "mp4"
        )
        if playable.count == 1 {
            try FileManager.default.moveItem(at: playable[0], to: destination)
        } else {
            try await SegmentJoiner.join(playable, into: destination)
        }
        return destination
    }

    /// Moves the playable segments into the output folder as `… part 1.mp4`, `… part 2.mp4`, for when joining
    /// failed, so nothing recorded is lost. Returns the moved files.
    @concurrent
    func salvage(_ segments: [URL], startedAt date: Date) async -> [URL] {
        var saved: [URL] = []
        let base = RecordingFileNamer.baseName(for: date)
        for url in segments where await Self.hasFrames(url) {
            let destination = RecordingFileNamer.uniqueURL(
                in: outputFolder,
                baseName: "\(base) part \(saved.count + 1)",
                pathExtension: "mp4"
            )
            if (try? FileManager.default.moveItem(at: url, to: destination)) != nil {
                saved.append(destination)
            }
        }
        return saved
    }

    /// Deletes a recording's scratch folder.
    func discard(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Whether the file is a movie with a video track and a duration.
    private static func hasFrames(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.isNumeric, duration > .zero,
              let tracks = try? await asset.loadTracks(withMediaType: .video)
        else {
            return false
        }
        return !tracks.isEmpty
    }
}
