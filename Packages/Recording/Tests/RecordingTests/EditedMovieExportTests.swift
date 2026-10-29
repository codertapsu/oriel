import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
@testable import Recording
import Testing
import UniformTypeIdentifiers

struct EditedMovieExportTests {
    private func export(
        _ source: URL,
        to destination: URL,
        edit: VideoEdit = VideoEdit(),
        options: VideoExportOptions = VideoExportOptions()
    ) async throws {
        try await EditedMovieExporter.export(EditedMovieExporter.Request(
            source: source,
            destination: destination,
            edit: edit,
            options: options
        ))
    }

    private func videoTrack(of url: URL) async throws -> AVAssetTrack {
        try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
    }

    private func frame(of url: URL, at time: Double) async throws -> CGImage {
        try await FrameReader.image(of: url, at: time)
    }

    @Test func trimsAndExportsAnMPEG4MovieAtTheOriginalSize() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 3)
        let output = folder.file("trimmed.mp4")

        try await export(source, to: output, edit: VideoEdit(trimStart: 0.5, trimEnd: 2))

        let asset = AVURLAsset(url: output)
        #expect(try await abs(asset.load(.duration).seconds - 1.5) <= 0.1)
        let track = try await videoTrack(of: output)
        #expect(try await track.load(.naturalSize) == CGSize(width: 320, height: 180))
        #expect(try await track.load(.formatDescriptions).allSatisfy { $0.mediaSubType == .h264 })
        // Nothing is left of the hidden file the export wrote first.
        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted()
        #expect(contents == ["source.mp4", "trimmed.mp4"], "\(contents)")
    }

    @Test func exportsHEVCInAQuickTimeMovieScaledTo720p() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, width: 1920, height: 1080, duration: 1)
        let output = folder.file("small.mov")

        try await export(source, to: output, options: VideoExportOptions(format: .mov, codec: .hevc, size: .hd))

        let track = try await videoTrack(of: output)
        #expect(try await track.load(.naturalSize) == CGSize(width: 1280, height: 720))
        #expect(try await track.load(.formatDescriptions).allSatisfy { $0.mediaSubType == .hevc })
        let header = try FileHandle(forReadingFrom: output).read(upToCount: 12) ?? Data()
        #expect(String(bytes: header.dropFirst(4).prefix(8), encoding: .ascii) == "ftypqt  ")
    }

    @Test func writesAChapterTrackThatAVFoundationReads() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 6)
        var edit = VideoEdit(trimStart: 1)
        edit.addChapter(at: 0, title: "Intro")
        edit.addChapter(at: 2.5, title: "Démo — 日本語")
        edit.addChapter(at: 4, title: "Questions")

        for format in [VideoExportFormat.mp4, .mov] {
            let output = folder.file("chapters.\(format.fileExtension)")
            try await export(source, to: output, edit: edit, options: VideoExportOptions(format: format))

            let chapters = try #require(try await ChapterTrack.chapters(of: AVURLAsset(url: output)))
            #expect(chapters.map(\.title) == ["Intro", "Démo — 日本語", "Questions"])
            #expect(chapters.map(\.start) == [0, 1.5, 3])
            #expect(abs((chapters.last?.end ?? 0) - 5) < 0.01)
            // The chapter track is listed as the video's chapters and plays no part itself.
            let text = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .text).first)
            #expect(try await !text.load(.isEnabled))
        }
    }

    @Test func leavesOutTheChapterTrackWithoutMarkers() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 1)
        let output = folder.file("plain.mp4")

        try await export(source, to: output)

        #expect(try await AVURLAsset(url: output).loadTracks(withMediaType: .text).isEmpty)
        #expect(try await ChapterTrack.chapters(of: AVURLAsset(url: output)) == nil)
    }

    @Test func zoomsIntoTheFocusPointWithoutBorders() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        // A still screen: two frames in three seconds, as ScreenCaptureKit records one.
        let source = folder.file("quadrants.mp4")
        try await PatternMovie.write(to: source, frameTimes: [0, 2], duration: 3)
        // Three times into the middle of the red top-left quarter, clear of the other colours.
        let zoom = ZoomSegment(start: 0.5, end: 2.5, scale: 3, focus: [ZoomFocus(time: 0.5, point: CGPoint(x: 0.25, y: 0.25))])
        let output = folder.file("zoomed.mp4")

        try await export(source, to: output, edit: VideoEdit(zoomSegments: [zoom]))

        let zoomed = try await frame(of: output, at: 1.5)
        // Red fills the frame, edges included.
        for (x, y) in [(2, 2), (zoomed.width - 3, 2), (2, zoomed.height - 3), (zoomed.width - 3, zoomed.height - 3)] {
            #expect(PatternMovie.isClose(PatternMovie.colour(in: zoomed, x: x, y: y), 0xFF0000), "at \(x), \(y)")
        }
        let whole = try await frame(of: output, at: 0.1)
        #expect(PatternMovie.isClose(PatternMovie.colour(in: whole, x: whole.width - 3, y: whole.height - 3), 0xFFFFFF))
        // The zoom has frames of its own across the still screen.
        let rate = try await videoTrack(of: output).load(.nominalFrameRate)
        #expect(rate >= 24)
        #expect(try await abs(AVURLAsset(url: output).load(.duration).seconds - 3) <= 0.1)
    }

    @Test func keepsTheLengthOfAStillMovie() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("still.mp4")
        try await PatternMovie.write(to: source, frameTimes: [0, 0.5], duration: 3)
        let output = folder.file("still-out.mp4")

        try await export(source, to: output)

        #expect(try await abs(AVURLAsset(url: output).load(.duration).seconds - 3) <= 0.1)
    }

    @Test func mixesSoundIntoOneStereoTrack() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("sound.mp4")
        try await PatternMovie.write(to: source, frameTimes: [0, 1], duration: 2, audioTracks: 2)
        let output = folder.file("sound-out.mp4")

        try await export(source, to: output, edit: VideoEdit(trimEnd: 1.5))

        let audio = try await AVURLAsset(url: output).loadTracks(withMediaType: .audio)
        #expect(audio.count == 1)
        let format = try #require(try await audio.first?.load(.formatDescriptions).first)
        #expect(format.mediaSubType == .mpeg4AAC)
        #expect(format.audioStreamBasicDescription?.mChannelsPerFrame == 2)
        #expect(try await abs(AVURLAsset(url: output).load(.duration).seconds - 1.5) <= 0.1)
    }

    @Test func exportsATrimmedZoomedGIF() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("quadrants.mp4")
        try await PatternMovie.write(to: source, width: 640, height: 360, frameTimes: [0], duration: 3)
        let zoom = ZoomSegment(start: 0, end: 3, scale: 2, focus: [ZoomFocus(time: 0, point: CGPoint(x: 0.75, y: 0.75))])
        let output = folder.file("clip.gif")
        var options = VideoExportOptions(format: .gif)
        options.gif = GIFExportOptions(frameRate: 10, maxWidth: 320)

        try await export(source, to: output, edit: VideoEdit(trimStart: 1, trimEnd: 2, zoomSegments: [zoom]), options: options)

        let gif = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        #expect(CGImageSourceGetType(gif) as String? == UTType.gif.identifier)
        #expect(CGImageSourceGetCount(gif) == 10)
        let first = try #require(CGImageSourceCreateImageAtIndex(gif, 5, nil))
        #expect(first.width == 320 && first.height == 180)
        // Zoomed into the white bottom-right quarter.
        #expect(PatternMovie.isClose(PatternMovie.colour(in: first, x: 4, y: 4), 0xFFFFFF, tolerance: 60))
    }

    @Test func reportsProgressUpToTheEnd() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 2)
        let output = folder.file("out.mp4")
        let reports = ProgressLog()

        try await EditedMovieExporter.export(
            EditedMovieExporter.Request(source: source, destination: output, edit: VideoEdit(), options: VideoExportOptions())
        ) { reports.append($0) }

        let values = reports.values
        #expect(values.last == 1)
        #expect(values == values.sorted())
        #expect(values.count >= 10)
    }

    @Test func replacesAnExistingFileButNeverTheSource() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 1)
        let output = folder.file("existing.mp4")
        try Data("old".utf8).write(to: output)

        try await export(source, to: output)
        #expect(try await AVURLAsset(url: output).load(.isPlayable))

        await #expect(throws: VideoEditorError.replacesSource) {
            try await export(source, to: source)
        }
        #expect(try await AVURLAsset(url: source).load(.isPlayable))
    }

    @Test func refusesAnExportTooShortToKeep() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, duration: 1)

        await #expect(throws: VideoEditorError.tooShort) {
            try await export(source, to: folder.file("out.mp4"), edit: VideoEdit(trimStart: 0.95))
        }
    }

    @Test func cancellingLeavesNothingBehind() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let source = folder.file("source.mp4")
        try await TestMovie.write(to: source, width: 1280, height: 720, duration: 8)
        let output = folder.file("cancelled.mp4")

        let task = Task {
            try await export(source, to: output, edit: VideoEdit(zoomSegments: [ZoomSegment(start: 0, end: 8, scale: 2, focus: [])]))
        }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path) == ["source.mp4"])
    }
}

/// Collects progress reports from the exporter's threads.
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [Double] = []

    func append(_ value: Double) {
        lock.withLock { reports.append(value) }
    }

    var values: [Double] {
        lock.withLock { reports }
    }
}
