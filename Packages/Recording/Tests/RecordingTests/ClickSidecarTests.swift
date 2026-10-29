import CoreGraphics
import Foundation
@testable import Recording
import Testing

struct ClickSidecarTests {
    private let sample = ClickSidecar(
        width: 1920,
        height: 1080,
        duration: 12.5,
        clicks: [
            ClickRecord(time: 4.25, x: 0.75, y: 0.5, button: .right),
            ClickRecord(time: 1.5, x: 0.25, y: 0.125),
        ]
    )

    @Test func keepsClicksInTimeOrder() {
        #expect(sample.clicks.map(\.time) == [1.5, 4.25])
    }

    @Test func roundTripsThroughJSON() throws {
        let decoded = try ClickSidecar.decode(sample.encoded())
        #expect(decoded == sample)
    }

    @Test func writesAVersionedCompactFormat() throws {
        let json = try #require(String(data: sample.encoded(), encoding: .utf8))
        #expect(json.hasPrefix(#"{"clicks":[{"button":"left","time":1.5,"x":0.25,"y":0.125}"#))
        #expect(json.contains(#""format":"oriel-clicks""#))
        #expect(json.contains(#""version":1"#))
        #expect(json.contains(#""width":1920"#))
        #expect(!json.contains("\n"))
    }

    @Test func readsAHandWrittenFile() throws {
        let json = #"""
        {"format":"oriel-clicks","version":1,"width":800,"height":600,"duration":3,
         "clicks":[{"time":0.5,"x":0.1,"y":0.9,"button":"other"}]}
        """#
        let decoded = try ClickSidecar.decode(Data(json.utf8))
        #expect(decoded.clicks == [ClickRecord(time: 0.5, x: 0.1, y: 0.9, button: .other)])
        #expect(decoded.width == 800)
    }

    @Test func refusesANewerVersion() {
        let json = #"{"format":"oriel-clicks","version":2,"clicks":"something else"}"#
        #expect(throws: ClickSidecar.ReadError.unsupportedVersion(2)) {
            try ClickSidecar.decode(Data(json.utf8))
        }
    }

    @Test(arguments: [
        #"{"format":"something","version":1}"#,
        #"[1, 2, 3]"#,
        "not json",
    ])
    func refusesOtherFiles(_ json: String) {
        #expect(throws: ClickSidecar.ReadError.notAClickFile) {
            try ClickSidecar.decode(Data(json.utf8))
        }
    }

    @Test func dropsClicksThatCannotBeUsed() throws {
        let json = #"""
        {"format":"oriel-clicks","version":1,"width":10,"height":10,"duration":3,"clicks":[
          {"time":-1,"x":0.5,"y":0.5,"button":"left"},
          {"time":1,"x":1.5,"y":0.5,"button":"left"},
          {"time":2,"x":0.5,"y":0.5,"button":"left"}]}
        """#
        let decoded = try ClickSidecar.decode(Data(json.utf8))
        #expect(decoded.clicks.map(\.time) == [2])
    }

    @Test func liesNextToTheMovie() {
        let movie = URL(filePath: "/Users/someone/Movies/Oriel Recording 2026-10-29 at 14.05.09.mp4")
        #expect(ClickSidecar.url(for: movie).path == "/Users/someone/Movies/Oriel Recording 2026-10-29 at 14.05.09.oriel-clicks.json")
    }

    @Test func writesAndLoadsNextToAMovie() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let movie = folder.file("clip.mp4")
        #expect(try ClickSidecar.load(for: movie) == nil)

        try sample.write(nextTo: movie)

        #expect(try ClickSidecar.load(for: movie) == sample)
    }

    @Test func trimmingKeepsAndShiftsTheClicksInside() {
        let trimmed = sample.trimmed(to: 1.0 ... 4.0)
        #expect(trimmed.clicks == [ClickRecord(time: 0.5, x: 0.25, y: 0.125)])
        #expect(trimmed.duration == 3.0)
        #expect(trimmed.width == 1920)
    }
}

struct ClickLogTests {
    /// A 400 × 300 pt area whose bottom-left corner is at (100, 50) in Cocoa screen coordinates.
    private let area = CGRect(x: 100, y: 50, width: 400, height: 300)

    @Test func normalizesWithATopLeftOrigin() throws {
        let topLeft = try #require(ClickLog.normalized(CGPoint(x: 100, y: 350), in: area))
        #expect(topLeft == CGPoint(x: 0, y: 0))
        let bottomRight = try #require(ClickLog.normalized(CGPoint(x: 500, y: 50), in: area))
        #expect(bottomRight == CGPoint(x: 1, y: 1))
        let middle = try #require(ClickLog.normalized(CGPoint(x: 200, y: 275), in: area))
        #expect(middle == CGPoint(x: 0.25, y: 0.25))
    }

    @Test func ignoresClicksOutsideTheArea() {
        #expect(ClickLog.normalized(CGPoint(x: 99, y: 100), in: area) == nil)
        #expect(ClickLog.normalized(CGPoint(x: 200, y: 351), in: area) == nil)
        var log = ClickLog(area: area, pixelWidth: 800, pixelHeight: 600)
        let kept = log.record(CGPoint(x: 600, y: 100), button: .left, segment: 0, offset: 1)
        #expect(!kept)
        #expect(log.entries.isEmpty)
    }

    @Test func placesClicksOnTheJoinedTimeline() {
        var log = ClickLog(area: area, pixelWidth: 800, pixelHeight: 600)
        log.record(CGPoint(x: 300, y: 200), button: .left, segment: 0, offset: 1.25)
        // Segment 1 was unplayable and dropped from the movie, so its click goes too.
        log.record(CGPoint(x: 300, y: 200), button: .left, segment: 1, offset: 0.5)
        log.record(CGPoint(x: 100, y: 350), button: .right, segment: 2, offset: 0.333_333)
        let starts = ClickLog.segmentStarts(durations: [(0, 4.0), (1, nil), (2, 3.0)])
        #expect(starts == [0: 0, 2: 4.0])

        let sidecar = log.sidecar(segmentStarts: starts, duration: 7.0)

        #expect(sidecar.clicks == [
            ClickRecord(time: 1.25, x: 0.5, y: 0.5),
            ClickRecord(time: 4.333, x: 0, y: 0, button: .right),
        ])
        #expect(sidecar.width == 800)
        #expect(sidecar.height == 600)
        #expect(sidecar.duration == 7.0)
    }

    @Test func dropsClicksPastTheEndOfTheMovie() {
        var log = ClickLog(area: area, pixelWidth: 800, pixelHeight: 600)
        log.record(CGPoint(x: 300, y: 200), button: .left, segment: 0, offset: 5.5)
        #expect(log.sidecar(segmentStarts: [0: 0], duration: 5.0).clicks.isEmpty)
    }

    @Test func refusesNegativeOffsets() {
        var log = ClickLog(area: area, pixelWidth: 800, pixelHeight: 600)
        let kept = log.record(CGPoint(x: 300, y: 200), button: .left, segment: 0, offset: -0.1)
        #expect(!kept)
    }
}
