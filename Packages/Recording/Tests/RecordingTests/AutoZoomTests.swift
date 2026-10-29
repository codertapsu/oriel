import CoreGraphics
import Foundation
@testable import Recording
import Testing

struct AutoZoomTests {
    private let settings = AutoZoomSettings(level: 2, hold: 1.5)

    private func segments(_ clicks: [ClickRecord], duration: Double = 60, settings: AutoZoomSettings? = nil) -> [ZoomSegment] {
        AutoZoom.segments(for: clicks, duration: duration, settings: settings ?? self.settings)
    }

    @Test func zoomsInJustBeforeAClickAndOutAfterTheHold() throws {
        let result = segments([ClickRecord(time: 10, x: 0.4, y: 0.6)])

        let segment = try #require(result.first)
        #expect(result.count == 1)
        #expect(abs(segment.start - (10 - 0.5 - 0.2)) < 1e-9)
        #expect(abs(segment.end - (10 + 1.5 + 0.5)) < 1e-9)
        #expect(segment.scale == 2)
        #expect(segment.focus == [ZoomFocus(time: 10, point: CGPoint(x: 0.4, y: 0.6))])
        // Fully zoomed in by the time of the click, out again at the end.
        #expect(segment.progress(at: 10 - AutoZoomSettings.lead - 0.01) > 0.99)
        #expect(segment.state(at: 10) == ZoomState(scale: 2, center: CGPoint(x: 0.4, y: 0.6)))
        #expect(abs(segment.scale(at: segment.end) - 1) < 1e-9)
    }

    @Test func mergesClicksCloseInTimeIntoOneSegmentThatPans() throws {
        let result = segments([
            ClickRecord(time: 5, x: 0.2, y: 0.3),
            ClickRecord(time: 7, x: 0.8, y: 0.7),
        ])

        let segment = try #require(result.first)
        #expect(result.count == 1)
        #expect(abs(segment.start - 4.3) < 1e-9)
        #expect(abs(segment.end - 9.0) < 1e-9)
        #expect(segment.focus.map(\.time) == [5, 7])
        // Still at the first click until the pan starts, at the second one before it happens.
        #expect(segment.center(at: 6.0) == CGPoint(x: 0.25, y: 0.3))
        #expect(segment.center(at: 7 - ZoomSegment.panLead) == CGPoint(x: 0.75, y: 0.7))
        let midway = segment.center(at: 7 - ZoomSegment.panLead - ZoomSegment.panDuration / 2)
        #expect(abs(midway.x - 0.5) < 1e-9)
    }

    @Test func keepsClicksFarApartInTimeSeparate() {
        let result = segments([ClickRecord(time: 5, x: 0.5, y: 0.5), ClickRecord(time: 15, x: 0.5, y: 0.5)])

        #expect(result.count == 2)
        #expect(result[0].end < result[1].start)
    }

    @Test func mergesWhenTheGapBetweenZoomsWouldBeShort() {
        let interval = settings.groupingInterval
        let together = segments([ClickRecord(time: 5, x: 0.5, y: 0.5), ClickRecord(time: 5 + interval - 0.01, x: 0.5, y: 0.5)])
        let apart = segments([ClickRecord(time: 5, x: 0.5, y: 0.5), ClickRecord(time: 5 + interval + 0.01, x: 0.5, y: 0.5)])

        #expect(together.count == 1)
        #expect(apart.count == 2)
        #expect(apart[1].start - apart[0].end >= AutoZoomSettings.mergeGap)
    }

    @Test func doesNotPanForANearbyClick() throws {
        let result = segments([
            ClickRecord(time: 5, x: 0.5, y: 0.5),
            ClickRecord(time: 6, x: 0.55, y: 0.45),
            ClickRecord(time: 6.2, x: 0.56, y: 0.45),
        ])

        let segment = try #require(result.first)
        #expect(segment.focus.count == 1)
        #expect(segment.center(at: 7) == CGPoint(x: 0.5, y: 0.5))
    }

    @Test func clampsFocusPointsSoTheViewStaysInsideTheFrame() throws {
        let result = segments([ClickRecord(time: 5, x: 0.02, y: 0.99)], settings: AutoZoomSettings(level: 2.5, hold: 1))

        let point = try #require(result.first?.focus.first?.point)
        #expect(abs(point.x - 0.2) < 1e-9)
        #expect(abs(point.y - 0.8) < 1e-9)
    }

    @Test func skipsAPanThatClampingWouldUndo() throws {
        // Both clicks are near the right edge: clamped, they look at the same place.
        let result = segments([ClickRecord(time: 5, x: 0.8, y: 0.5), ClickRecord(time: 6, x: 0.99, y: 0.5)])

        #expect(try #require(result.first).focus.count == 1)
    }

    @Test func staysInsideTheMovie() throws {
        let early = try #require(segments([ClickRecord(time: 0.1, x: 0.5, y: 0.5)]).first)
        #expect(early.start == 0)
        let late = try #require(segments([ClickRecord(time: 9.9, x: 0.5, y: 0.5)], duration: 10).first)
        #expect(late.end == 10)
        #expect(segments([ClickRecord(time: 12, x: 0.5, y: 0.5)], duration: 10).isEmpty)
    }

    @Test func ignoresUnusableClicksAndEmptyMovies() {
        #expect(segments([]).isEmpty)
        #expect(segments([ClickRecord(time: .nan, x: 0.5, y: 0.5)]).isEmpty)
        #expect(segments([ClickRecord(time: 1, x: 0.5, y: 0.5)], duration: 0).isEmpty)
    }

    @Test func clampsItsSettings() {
        #expect(AutoZoomSettings(level: 5, hold: 0.1) == AutoZoomSettings(level: 3, hold: 0.5))
        #expect(AutoZoomSettings(level: 1, hold: 60) == AutoZoomSettings(level: 1.5, hold: 5))
    }
}

struct ZoomSegmentTests {
    private let segment = ZoomSegment(start: 2, end: 6, scale: 2, focus: [ZoomFocus(time: 2.5, point: CGPoint(x: 0.3, y: 0.4))])

    @Test func easesInAndOut() {
        #expect(segment.progress(at: 1.9) == 0)
        #expect(segment.progress(at: 2) == 0)
        #expect(abs(segment.progress(at: 2.25) - 0.5) < 1e-9)
        #expect(segment.progress(at: 2.5) == 1)
        #expect(segment.progress(at: 4) == 1)
        #expect(abs(segment.progress(at: 5.75) - 0.5) < 1e-9)
        #expect(segment.progress(at: 6) == 0)
        // Starts and ends at rest: barely moving a moment after the start.
        #expect(segment.progress(at: 2.005) < 0.0001)
    }

    @Test func zoomsGeometrically() {
        #expect(abs(segment.scale(at: 2.25) - sqrt(2)) < 1e-9)
        #expect(segment.scale(at: 3) == 2)
        #expect(segment.scale(at: 7) == 1)
    }

    @Test func shortSegmentsRampFaster() {
        let short = ZoomSegment(start: 0, end: 0.6, scale: 2, focus: [])
        #expect(short.rampDuration == 0.3)
        #expect(short.progress(at: 0.3) == 1)
        #expect(short.focus == [ZoomFocus(time: 0, point: CGPoint(x: 0.5, y: 0.5))])
    }

    @Test func clampsItsScale() {
        #expect(ZoomSegment(start: 0, end: 1, scale: 9, focus: []).scale == 3)
        #expect(ZoomSegment(start: 0, end: 1, scale: 1, focus: []).scale == 1.5)
    }

    @Test func picksTheFocusPointBeingShown() {
        let panning = ZoomSegment(
            start: 0,
            end: 10,
            scale: 2,
            focus: [ZoomFocus(time: 1, point: CGPoint(x: 0.3, y: 0.3)), ZoomFocus(time: 5, point: CGPoint(x: 0.7, y: 0.7))]
        )
        #expect(panning.focusIndex(at: 0.5) == 0)
        #expect(panning.focusIndex(at: 4.0) == 0)
        #expect(panning.focusIndex(at: 4.5) == 1)
        #expect(panning.focusIndex(at: 9) == 1)
    }

    @Test func aPlanPicksTheSegmentAtTheTime() {
        let other = ZoomSegment(start: 8, end: 10, scale: 3, focus: [ZoomFocus(time: 8, point: CGPoint(x: 0.6, y: 0.6))])
        let plan = ZoomPlan(segments: [other, segment])

        #expect(plan.segments.map(\.start) == [2, 8])
        #expect(plan.state(at: 1) == .identity)
        #expect(plan.state(at: 4) == ZoomState(scale: 2, center: CGPoint(x: 0.3, y: 0.4)))
        #expect(plan.state(at: 9).scale == 3)
        #expect(plan.state(at: 7) == .identity)
    }

    @Test func trimmingAPlanMovesItToTheNewStart() {
        let plan = ZoomPlan(segments: [segment, ZoomSegment(start: 20, end: 22, scale: 2, focus: [])])

        let trimmed = plan.trimmed(to: 1 ... 10)

        #expect(trimmed.segments.count == 1)
        #expect(trimmed.segments[0].start == 1)
        #expect(trimmed.segments[0].end == 5)
        #expect(trimmed.segments[0].focus[0].time == 1.5)
        #expect(trimmed.state(at: 3) == plan.state(at: 4))
    }

    @Test func smoothEasingIsSymmetricAndClamped() {
        #expect(Easing.smooth(-1) == 0)
        #expect(Easing.smooth(2) == 1)
        #expect(Easing.smooth(.nan) == 0)
        #expect(abs(Easing.smooth(0.3) + Easing.smooth(0.7) - 1) < 1e-12)
    }
}

struct ZoomTransformTests {
    private let source = CGSize(width: 3024, height: 1964)

    @Test func showsTheWholeFrameUnzoomed() {
        #expect(ZoomTransform.cropRect(for: .identity, sourceSize: source) == CGRect(origin: .zero, size: source))
    }

    @Test func cropsAroundTheCenter() {
        let crop = ZoomTransform.cropRect(for: ZoomState(scale: 2, center: CGPoint(x: 0.5, y: 0.5)), sourceSize: source)
        #expect(crop == CGRect(x: 756, y: 491, width: 1512, height: 982))
    }

    @Test(arguments: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: -3, y: 0.5), CGPoint(x: 0.5, y: 7)])
    func neverLeavesTheFrame(_ center: CGPoint) {
        for scale in [1.0, 1.5, 2, 3] {
            let crop = ZoomTransform.cropRect(for: ZoomState(scale: scale, center: center), sourceSize: source)
            #expect(crop.minX >= 0 && crop.minY >= 0)
            #expect(crop.maxX <= source.width + 1e-9 && crop.maxY <= source.height + 1e-9)
            #expect(abs(crop.width - source.width / scale) < 1e-9)
        }
    }

    @Test(arguments: [CGSize(width: 1920, height: 1246), CGSize(width: 1108, height: 720), CGSize(width: 3024, height: 1964)])
    func fillsTheOutputExactly(_ output: CGSize) {
        let state = ZoomState(scale: 2.5, center: CGPoint(x: 0.9, y: 0.1))
        let crop = ZoomTransform.cropRect(for: state, sourceSize: source)

        let transform = ZoomTransform.transform(crop: crop, sourceSize: source, outputSize: output)

        // The crop in Core Image coordinates (bottom-left origin) lands exactly on the output.
        let ciCrop = CGRect(x: crop.minX, y: source.height - crop.maxY, width: crop.width, height: crop.height)
        let mapped = ciCrop.applying(transform)
        #expect(abs(mapped.minX) < 1e-6 && abs(mapped.minY) < 1e-6)
        #expect(abs(mapped.width - output.width) < 1e-6 && abs(mapped.height - output.height) < 1e-6)
    }

    @Test func clampsCentersForAScale() {
        #expect(ZoomTransform.clampedCenter(CGPoint(x: 0.1, y: 0.95), scale: 2) == CGPoint(x: 0.25, y: 0.75))
        #expect(ZoomTransform.clampedCenter(CGPoint(x: 0.1, y: 0.9), scale: 1) == CGPoint(x: 0.5, y: 0.5))
        #expect(ZoomTransform.clampedCenter(CGPoint(x: 0.4, y: 0.6), scale: 2) == CGPoint(x: 0.4, y: 0.6))
    }
}
