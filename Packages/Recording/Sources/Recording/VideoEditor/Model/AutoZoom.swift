import CoreGraphics
import Foundation

/// Auto Zoom (PLAN §17): zoom segments made from a recording's clicks. Pure.
///
/// Every click is zoomed into: the zoom-in ends `AutoZoomSettings.lead` before it, the view holds for `hold`
/// after it, then zooms back out. Clicks close together in time share one segment, which pans from one to the
/// next, but only when the next click is outside the middle of the zoomed view, so a burst of nearby clicks does
/// not shake the picture. Focus points are clamped, so the view never leaves the frame.
nonisolated enum AutoZoom {
    /// The segments for `clicks` in a movie of `duration` seconds, in time order and never overlapping.
    /// `makeID` names each segment; tests pass a counter.
    static func segments(
        for clicks: [ClickRecord],
        duration: Double,
        settings: AutoZoomSettings,
        makeID: () -> UUID = UUID.init
    ) -> [ZoomSegment] {
        guard duration.isFinite, duration > 0 else { return [] }
        let usable = clicks.filter { $0.isValid && $0.time <= duration }.sorted { $0.time < $1.time }
        var groups: [[ClickRecord]] = []
        for click in usable {
            if let previous = groups.last?.last, click.time - previous.time <= settings.groupingInterval {
                groups[groups.count - 1].append(click)
            } else {
                groups.append([click])
            }
        }
        return groups.compactMap { segment(for: $0, duration: duration, settings: settings, id: makeID()) }
    }

    /// Whether a click at `click` is far enough from the middle of the view centred on `center` to pan to it.
    static func needsPan(from center: CGPoint, to click: CGPoint, scale: Double) -> Bool {
        let reach = 0.5 / max(scale, 1) * AutoZoomSettings.comfortZone
        return abs(click.x - center.x) > reach || abs(click.y - center.y) > reach
    }

    private static func segment(for group: [ClickRecord], duration: Double, settings: AutoZoomSettings, id: UUID) -> ZoomSegment? {
        guard let first = group.first, let last = group.last else { return nil }
        let start = max(0, first.time - ZoomSegment.transition - AutoZoomSettings.lead)
        var end = min(duration, last.time + settings.hold + ZoomSegment.transition)
        if end - start < ZoomSegment.minimumDuration {
            end = min(duration, start + ZoomSegment.minimumDuration)
        }
        guard end > start else { return nil }
        var focus: [ZoomFocus] = []
        for click in group {
            let position = CGPoint(x: click.x, y: click.y)
            let point = ZoomTransform.clampedCenter(position, scale: settings.level)
            if let current = focus.last {
                let moves = hypot(point.x - current.point.x, point.y - current.point.y) > 0.001
                guard moves, needsPan(from: current.point, to: position, scale: settings.level) else { continue }
            }
            focus.append(ZoomFocus(time: click.time, point: point))
        }
        return ZoomSegment(id: id, start: start, end: end, scale: settings.level, focus: focus)
    }
}
