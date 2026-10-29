import CoreGraphics
import Foundation
@testable import Recording
import Testing

struct VideoEditTests {
    @Test func keepsTheWholeMovieUntilTrimmed() {
        let edit = VideoEdit()
        #expect(edit.isEmpty)
        #expect(edit.range(duration: 30) == 0 ... 30)
    }

    @Test func setsInAndOutPoints() {
        var edit = VideoEdit()
        edit.setTrimStart(5, duration: 30)
        edit.setTrimEnd(20, duration: 30)
        #expect(edit.range(duration: 30) == 5 ... 20)
        #expect(!edit.isEmpty)
    }

    @Test func anInPointAfterTheOutPointClearsTheOutPoint() {
        var edit = VideoEdit(trimStart: 5, trimEnd: 10)
        edit.setTrimStart(12, duration: 30)
        #expect(edit.trimStart == 12)
        #expect(edit.trimEnd == nil)

        edit.setTrimEnd(3, duration: 30)
        #expect(edit.trimEnd == 3)
        #expect(edit.trimStart == nil)
    }

    @Test func trimPointsAtTheEndsMeanNoTrim() {
        var edit = VideoEdit(trimStart: 5, trimEnd: 10)
        edit.setTrimStart(0, duration: 30)
        edit.setTrimEnd(30, duration: 30)
        #expect(edit.trimStart == nil)
        #expect(edit.trimEnd == nil)
    }

    @Test func clampsTheRangeToTheMovie() {
        let edit = VideoEdit(trimStart: -4, trimEnd: 99)
        #expect(edit.range(duration: 30) == 0 ... 30)
        #expect(VideoEdit(trimStart: 40).range(duration: 30) == 30 ... 30)
    }

    @Test func addsNumberedChaptersInTimeOrder() throws {
        var edit = VideoEdit()
        let added = edit.addChapter(at: 10)
        let second = try #require(added)
        let addedFirst = edit.addChapter(at: 2)
        let first = try #require(addedFirst)
        #expect(edit.chapters.map(\.id) == [first, second])
        #expect(edit.chapters.map(\.title) == ["Chapter 2", "Chapter 1"])
        let tooClose = edit.addChapter(at: 10.1)
        #expect(tooClose == nil)

        edit.renameChapter(first, to: "Intro")
        edit.moveChapter(first, to: 15, duration: 30)
        #expect(edit.chapters.map(\.title) == ["Chapter 1", "Intro"])

        edit.removeChapter(second)
        #expect(edit.chapters.map(\.time) == [15])
    }

    @Test func jumpsBetweenChapters() {
        var edit = VideoEdit()
        edit.addChapter(at: 5)
        edit.addChapter(at: 10)
        edit.addChapter(at: 20)
        #expect(edit.chapter(after: 5)?.time == 10)
        #expect(edit.chapter(after: 20) == nil)
        #expect(edit.chapter(before: 10.2)?.time == 5)
        #expect(edit.chapter(before: 10.8)?.time == 10)
        #expect(edit.chapter(before: 5) == nil)
    }

    @Test func addsAZoomThatFitsBeforeTheNextOne() throws {
        var edit = VideoEdit()
        let addedLater = edit.addZoom(at: 10, duration: 30, scale: 2, point: CGPoint(x: 0.5, y: 0.5))
        let later = try #require(addedLater)
        let addedEarlier = edit.addZoom(at: 8, duration: 30, scale: 2, point: CGPoint(x: 0.05, y: 0.5))
        let earlier = try #require(addedEarlier)

        #expect(edit.zoomSegments.map(\.id) == [earlier, later])
        #expect(edit.zoomSegments[0].end == 10)
        #expect(edit.zoomSegments[0].focus[0].point == CGPoint(x: 0.25, y: 0.5))
        let inside = edit.addZoom(at: 11, duration: 30, scale: 2, point: .zero)
        #expect(inside == nil)
        let noRoom = edit.addZoom(at: 29.8, duration: 30, scale: 2, point: .zero)
        #expect(noRoom == nil)
    }

    @Test func movesAZoomBetweenItsNeighbours() throws {
        var edit = VideoEdit(zoomSegments: [
            ZoomSegment(start: 0, end: 2, scale: 2, focus: []),
            ZoomSegment(start: 5, end: 7, scale: 2, focus: [ZoomFocus(time: 6, point: CGPoint(x: 0.5, y: 0.5))]),
            ZoomSegment(start: 10, end: 12, scale: 2, focus: []),
        ])
        let id = edit.zoomSegments[1].id

        edit.moveZoom(id, toStart: 6, duration: 30)
        var moved = try #require(edit.zoomSegment(id))
        #expect(moved.start == 6 && moved.end == 8)
        #expect(moved.focus[0].time == 7)

        edit.moveZoom(id, toStart: 9.5, duration: 30)
        moved = try #require(edit.zoomSegment(id))
        #expect(moved.start == 8 && moved.end == 10)

        edit.moveZoom(id, toStart: -3, duration: 30)
        moved = try #require(edit.zoomSegment(id))
        #expect(moved.start == 2 && moved.end == 4)
    }

    @Test func resizesAZoomWithinItsRoom() throws {
        var edit = VideoEdit(zoomSegments: [
            ZoomSegment(start: 0, end: 2, scale: 2, focus: []),
            ZoomSegment(start: 5, end: 7, scale: 2, focus: []),
        ])
        let id = edit.zoomSegments[1].id

        edit.resizeZoom(id, start: 1, duration: 9)
        #expect(edit.zoomSegment(id)?.start == 2)
        edit.resizeZoom(id, end: 20, duration: 9)
        #expect(edit.zoomSegment(id)?.end == 9)
        edit.resizeZoom(id, start: 8.9, duration: 9)
        let segment = try #require(edit.zoomSegment(id))
        #expect(abs(segment.duration - ZoomSegment.minimumDuration) < 1e-9)
    }

    @Test func aHigherZoomPullsFocusPointsInwards() throws {
        var edit = VideoEdit(zoomSegments: [
            ZoomSegment(start: 0, end: 4, scale: 1.5, focus: [ZoomFocus(time: 1, point: CGPoint(x: 0.7, y: 0.5))]),
        ])
        let id = edit.zoomSegments[0].id

        edit.setZoomScale(id, scale: 3)
        let segment = try #require(edit.zoomSegment(id))
        #expect(segment.scale == 3)
        #expect(segment.focus[0].point == CGPoint(x: 0.7, y: 0.5))

        edit.setZoomScale(id, scale: 2.5)
        edit.setZoomFocus(id, focusIndex: 0, point: CGPoint(x: 0.95, y: 0.02))
        #expect(edit.zoomSegment(id)?.focus[0].point == CGPoint(x: 0.8, y: 0.2))
        edit.setZoomScale(id, scale: 9)
        #expect(edit.zoomSegment(id)?.scale == 3)
    }

    @Test func autoZoomReplacesTheZooms() {
        var edit = VideoEdit(zoomSegments: [ZoomSegment(start: 0, end: 2, scale: 2, focus: [])])
        edit.replaceZoomSegments([ZoomSegment(start: 9, end: 10, scale: 2, focus: []), ZoomSegment(start: 3, end: 4, scale: 2, focus: [])])
        #expect(edit.zoomSegments.map(\.start) == [3, 9])
        #expect(edit.zoomPlan.segments.count == 2)
    }
}

struct TimelineMappingTests {
    @Test func fitsTheWholeMovieByDefault() {
        let mapping = TimelineMapping(duration: 60, width: 600)
        #expect(mapping.isFitted)
        #expect(mapping.x(for: 30) == 300)
        #expect(mapping.time(for: 150) == 15)
        #expect(mapping.time(for: -20) == 0)
        #expect(mapping.time(for: 900) == 60)
        #expect(mapping.zoomFraction == 0)
    }

    @Test func zoomsAroundTheAnchor() {
        var mapping = TimelineMapping(duration: 60, width: 600)
        mapping.zoom(by: 4, around: 300)
        #expect(mapping.visibleDuration == 15)
        #expect(abs(mapping.time(for: 300) - 30) < 1e-9)
        #expect(!mapping.isFitted)

        mapping.zoom(by: 1000, around: 0)
        #expect(mapping.visibleDuration == TimelineMapping.minimumVisibleDuration)
        #expect(abs(mapping.zoomFraction - 1) < 1e-9)

        mapping.zoom(by: 0.0001, around: 0)
        #expect(mapping.isFitted)
        #expect(mapping.visibleStart == 0)
    }

    @Test func scrollsWithinTheMovie() {
        var mapping = TimelineMapping(duration: 60, width: 600)
        mapping.zoom(by: 6, around: 0)
        mapping.scroll(by: 300)
        #expect(mapping.visibleStart == 5)
        mapping.scroll(by: 100_000)
        #expect(mapping.visibleEnd == 60)
        mapping.scroll(by: -100_000)
        #expect(mapping.visibleStart == 0)
    }

    @Test func revealsThePlayhead() {
        var mapping = TimelineMapping(duration: 60, width: 600)
        mapping.zoom(by: 6, around: 0)
        mapping.reveal(5)
        #expect(mapping.visibleStart == 0)
        mapping.reveal(25)
        #expect(mapping.visibleStart == 24)
        #expect(mapping.x(for: 25) > 0)
    }

    @Test func theSliderMapsLogarithmically() {
        var mapping = TimelineMapping(duration: 100, width: 600)
        mapping.setZoomFraction(0.5)
        #expect(abs(mapping.visibleDuration - 10) < 1e-9)
        #expect(abs(mapping.zoomFraction - 0.5) < 1e-9)
        mapping.setZoomFraction(0)
        #expect(mapping.isFitted)
    }
}

struct ShuttleTests {
    @Test func lSpeedsUpForwardAndJBackward() {
        var shuttle = Shuttle()
        shuttle.forward()
        #expect(shuttle.rate == 1)
        shuttle.forward()
        shuttle.forward()
        #expect(shuttle.rate == 4)
        shuttle.forward()
        shuttle.forward()
        #expect(shuttle.rate == 8)
        shuttle.reverse()
        #expect(shuttle.rate == -1)
        shuttle.reverse()
        #expect(shuttle.rate == -2)
        shuttle.forward()
        #expect(shuttle.rate == 1)
    }

    @Test func kAndSpaceStop() {
        var shuttle = Shuttle()
        shuttle.toggle()
        #expect(shuttle.rate == 1)
        shuttle.forward()
        shuttle.toggle()
        #expect(shuttle.rate == 0)
        shuttle.reverse()
        shuttle.stop()
        #expect(shuttle.rate == 0)
        shuttle.follow(0.5)
        #expect(shuttle.rate == 0.5)
    }
}

struct TimecodeTests {
    @Test(arguments: [
        (0.0, "0:00.00"),
        (7.25, "0:07.25"),
        (754.5, "12:34.50"),
        (3723.0, "1:02:03.00"),
        (-3.0, "0:00.00"),
    ])
    func writesTimes(_ seconds: Double, _ text: String) {
        #expect(Timecode.string(seconds) == text)
    }

    @Test func writesShortAndSpokenTimes() {
        #expect(Timecode.short(65.9) == "1:05")
        #expect(Timecode.short(3600) == "1:00:00")
        #expect(Timecode.spoken(7.24) == "7.2 seconds")
        #expect(Timecode.spoken(62) == "1 minute 2 seconds")
        #expect(Timecode.spoken(0) == "0 seconds")
        #expect(Timecode.spoken(3601) == "1 hour 1 second")
    }
}

struct VideoExportOptionsTests {
    private let laptop = CGSize(width: 3024, height: 1964)

    @Test func scalesDownToFitAndKeepsEvenSizes() {
        #expect(VideoExportSize.original.pixelSize(for: laptop, codec: .hevc) == laptop)
        #expect(VideoExportSize.fullHD.pixelSize(for: laptop, codec: .hevc) == CGSize(width: 1662, height: 1080))
        #expect(VideoExportSize.hd.pixelSize(for: laptop, codec: .hevc) == CGSize(width: 1108, height: 720))
        #expect(VideoExportSize.original.pixelSize(for: CGSize(width: 1001, height: 501), codec: .h264) == CGSize(width: 1000, height: 500))
    }

    @Test func neverScalesUp() {
        let small = CGSize(width: 800, height: 600)
        #expect(VideoExportSize.fullHD.pixelSize(for: small, codec: .h264) == small)
        #expect(!VideoExportSize.fullHD.isDistinct(for: small, codec: .h264))
        #expect(!VideoExportSize.hd.isDistinct(for: small, codec: .h264))
        #expect(VideoExportSize.hd.isDistinct(for: laptop, codec: .h264))
    }

    @Test func h264KeepsWithinItsLargestFrame() {
        let sixK = CGSize(width: 6016, height: 3384)
        #expect(VideoExportSize.original.pixelSize(for: sixK, codec: .h264) == CGSize(width: 4096, height: 2304))
        #expect(VideoExportSize.original.pixelSize(for: sixK, codec: .hevc) == sixK)
    }

    @Test func picksBitRatesForScreenContent() {
        let h264 = VideoExportOptions.videoBitRate(width: 1920, height: 1080, frameRate: 30, codec: .h264)
        #expect((7_000_000 ... 8_000_000).contains(h264))
        #expect(VideoExportOptions.videoBitRate(width: 1920, height: 1080, frameRate: 30, codec: .hevc) < h264)
        #expect(VideoExportOptions.videoBitRate(width: 2, height: 2, frameRate: 1, codec: .h264) == 1_000_000)
    }
}
