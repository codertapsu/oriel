import CoreGraphics
import Foundation

/// What the user changed in the video editor (PLAN §17): the trim, the zooms and the chapters. The movie itself
/// is never touched; an export applies these to a copy. Pure: every rule about what an edit may do lives here, so
/// it is tested without a window.
nonisolated struct VideoEdit: Equatable, Sendable {
    /// The shortest part of a movie that can be kept.
    static let minimumLength = 0.1
    /// How long a zoom added by hand lasts.
    static let addedZoomDuration = 3.0
    /// A chapter is not added this close to another one.
    static let chapterSpacing = 0.25

    /// Where the export starts; nil keeps the start of the movie.
    var trimStart: Double?
    /// Where the export ends; nil keeps the end of the movie.
    var trimEnd: Double?
    /// In start order, never overlapping.
    private(set) var zoomSegments: [ZoomSegment] = []
    /// In time order.
    private(set) var chapters: [ChapterMarker] = []

    init(trimStart: Double? = nil, trimEnd: Double? = nil, zoomSegments: [ZoomSegment] = [], chapters: [ChapterMarker] = []) {
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.zoomSegments = zoomSegments.sorted { $0.start < $1.start }
        self.chapters = chapters.sorted { $0.time < $1.time }
    }

    /// Whether an export would be the movie as it is, re-encoded.
    var isEmpty: Bool {
        trimStart == nil && trimEnd == nil && zoomSegments.isEmpty && chapters.isEmpty
    }

    var zoomPlan: ZoomPlan {
        ZoomPlan(segments: zoomSegments)
    }

    /// The part of a movie of `duration` seconds that an export keeps.
    func range(duration: Double) -> ClosedRange<Double> {
        let duration = max(duration, 0)
        let lower = min(max(trimStart ?? 0, 0), duration)
        let upper = min(max(trimEnd ?? duration, lower), duration)
        return lower ... upper
    }

    // MARK: Trim

    /// I: the export starts at `time`. An end that would come too soon after it is cleared.
    mutating func setTrimStart(_ time: Double, duration: Double) {
        let time = min(max(time, 0), max(duration - Self.minimumLength, 0))
        trimStart = time <= 0 ? nil : time
        if let end = trimEnd, end - time < Self.minimumLength {
            trimEnd = nil
        }
    }

    /// O: the export ends at `time`. A start that would come too late before it is cleared.
    mutating func setTrimEnd(_ time: Double, duration: Double) {
        let time = min(max(time, Self.minimumLength), duration)
        trimEnd = time >= duration ? nil : time
        if let start = trimStart, time - start < Self.minimumLength {
            trimStart = nil
        }
    }

    // MARK: Chapters

    /// M: a chapter at `time`, unless one is already within `chapterSpacing`, named "Chapter N" with the lowest
    /// number not in use. Returns the new marker's id.
    @discardableResult
    mutating func addChapter(at time: Double, title: String? = nil) -> UUID? {
        guard time.isFinite, time >= 0, !chapters.contains(where: { abs($0.time - time) < Self.chapterSpacing }) else { return nil }
        let used = Set(chapters.map(\.title))
        let number = (1 ... chapters.count + 1).first { !used.contains("Chapter \($0)") } ?? chapters.count + 1
        let marker = ChapterMarker(time: time, title: title ?? "Chapter \(number)")
        chapters.append(marker)
        chapters.sort { $0.time < $1.time }
        return marker.id
    }

    mutating func renameChapter(_ id: UUID, to title: String) {
        guard let index = chapters.firstIndex(where: { $0.id == id }) else { return }
        chapters[index].title = title
    }

    mutating func moveChapter(_ id: UUID, to time: Double, duration: Double) {
        guard let index = chapters.firstIndex(where: { $0.id == id }) else { return }
        chapters[index].time = min(max(time, 0), duration)
        chapters.sort { $0.time < $1.time }
    }

    mutating func removeChapter(_ id: UUID) {
        chapters.removeAll { $0.id == id }
    }

    /// The marker before `time`, for ↑: a marker less than half a second before it counts as the current one, so
    /// pressing ↑ twice goes back two chapters.
    func chapter(before time: Double) -> ChapterMarker? {
        chapters.last { $0.time < time - 0.5 }
    }

    /// The marker after `time`, for ↓.
    func chapter(after time: Double) -> ChapterMarker? {
        chapters.first { $0.time > time + 0.01 }
    }

    // MARK: Zoom

    /// Auto Zoom: replaces every zoom segment.
    mutating func replaceZoomSegments(_ segments: [ZoomSegment]) {
        zoomSegments = segments.sorted { $0.start < $1.start }
    }

    /// Z: a zoom of `addedZoomDuration` starting at `time` and looking at `point`, shortened to fit before the next
    /// segment and the end. Returns nil when `time` is inside a segment or there is no room.
    @discardableResult
    mutating func addZoom(at time: Double, duration: Double, scale: Double, point: CGPoint) -> UUID? {
        guard time.isFinite, !zoomSegments.contains(where: { $0.contains(time) }) else { return nil }
        let nextStart = zoomSegments.first { $0.start > time }?.start ?? duration
        let end = min(time + Self.addedZoomDuration, nextStart, duration)
        guard end - time >= ZoomSegment.minimumDuration else { return nil }
        let center = ZoomTransform.clampedCenter(point, scale: scale)
        let segment = ZoomSegment(start: time, end: end, scale: scale, focus: [ZoomFocus(time: time, point: center)])
        zoomSegments.append(segment)
        zoomSegments.sort { $0.start < $1.start }
        return segment.id
    }

    /// Moves a whole segment, with its focus points, so that it starts at `start`; it stops at its neighbours and
    /// at the ends of the movie.
    mutating func moveZoom(_ id: UUID, toStart start: Double, duration: Double) {
        guard let index = zoomSegments.firstIndex(where: { $0.id == id }) else { return }
        let (lower, upper) = room(around: index, duration: duration)
        let segment = zoomSegments[index]
        let length = min(segment.duration, upper - lower)
        let clamped = min(max(start, lower), upper - length)
        var moved = segment.shifted(by: clamped - segment.start)
        moved.end = moved.start + length
        zoomSegments[index] = moved
    }

    /// Drags a segment's start or end (nil leaves it), keeping the segment between its neighbours and at least
    /// `ZoomSegment.minimumDuration` long. Focus points stay where they are in the movie.
    mutating func resizeZoom(_ id: UUID, start: Double? = nil, end: Double? = nil, duration: Double) {
        guard let index = zoomSegments.firstIndex(where: { $0.id == id }) else { return }
        let (lower, upper) = room(around: index, duration: duration)
        var segment = zoomSegments[index]
        if let start {
            segment.start = min(max(start, lower), segment.end - ZoomSegment.minimumDuration)
        }
        if let end {
            segment.end = min(max(end, segment.start + ZoomSegment.minimumDuration), upper)
        }
        guard segment.end - segment.start >= ZoomSegment.minimumDuration - 0.0001 else { return }
        zoomSegments[index] = segment
    }

    /// Where segment `index` may lie: from the previous segment's end to the next one's start.
    private func room(around index: Int, duration: Double) -> (lower: Double, upper: Double) {
        let lower = index > 0 ? zoomSegments[index - 1].end : 0
        let upper = index + 1 < zoomSegments.count ? zoomSegments[index + 1].start : max(duration, lower)
        return (lower, upper)
    }

    mutating func setZoomScale(_ id: UUID, scale: Double) {
        guard let index = zoomSegments.firstIndex(where: { $0.id == id }) else { return }
        let scale = min(max(scale, ZoomSegment.scales.lowerBound), ZoomSegment.scales.upperBound)
        zoomSegments[index].scale = scale
        // A higher zoom shows less, so focus points near an edge move inwards to stay inside the frame.
        for focus in zoomSegments[index].focus.indices {
            zoomSegments[index].focus[focus].point = ZoomTransform.clampedCenter(zoomSegments[index].focus[focus].point, scale: scale)
        }
    }

    /// Points focus point `focusIndex` of a segment at `point`, kept inside the frame at the segment's zoom.
    mutating func setZoomFocus(_ id: UUID, focusIndex: Int, point: CGPoint) {
        guard let index = zoomSegments.firstIndex(where: { $0.id == id }),
              zoomSegments[index].focus.indices.contains(focusIndex)
        else {
            return
        }
        zoomSegments[index].focus[focusIndex].point = ZoomTransform.clampedCenter(point, scale: zoomSegments[index].scale)
    }

    mutating func removeZoom(_ id: UUID) {
        zoomSegments.removeAll { $0.id == id }
    }

    func zoomSegment(_ id: UUID) -> ZoomSegment? {
        zoomSegments.first { $0.id == id }
    }
}
