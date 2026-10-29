import CoreGraphics
import Foundation

/// A stretch of the movie shown zoomed in (PLAN §17): the view zooms in from `start`, holds, and zooms back out
/// by `end`, panning between its focus points on the way. Pure.
///
/// The zoom-in and zoom-out each take `transition` seconds (less in a short segment) and ease in and out. The
/// scale changes geometrically (by equal ratios per frame), which looks like steady motion; a linear change would
/// seem to rush at the start.
nonisolated struct ZoomSegment: Equatable, Identifiable, Sendable {
    /// How long zooming in, and zooming out, take.
    static let transition = 0.5
    /// How long a pan from one focus point to the next takes, at most.
    static let panDuration = 0.6
    /// How long before its focus time a pan arrives, so the view is still when the click happens.
    static let panLead = 0.1
    /// The zoom levels the editor offers.
    static let scales: ClosedRange<Double> = 1.5 ... 3
    /// The shortest a segment may be.
    static let minimumDuration = 0.5

    let id: UUID
    /// When zooming in begins, in seconds from the start of the movie.
    var start: Double
    /// When zooming out has finished.
    var end: Double
    /// The zoom level while held.
    var scale: Double
    /// Where the view looks, in time order; never empty.
    var focus: [ZoomFocus]

    init(id: UUID = UUID(), start: Double, end: Double, scale: Double, focus: [ZoomFocus]) {
        self.id = id
        self.start = start
        self.end = max(end, start)
        self.scale = min(max(scale, Self.scales.lowerBound), Self.scales.upperBound)
        let sorted = focus.sorted { $0.time < $1.time }
        self.focus = sorted.isEmpty ? [ZoomFocus(time: start, point: CGPoint(x: 0.5, y: 0.5))] : sorted
    }

    var duration: Double {
        end - start
    }

    /// How long zooming in, and zooming out, each take: `transition`, or half the segment when it is shorter.
    var rampDuration: Double {
        min(Self.transition, max(duration, 0) / 2)
    }

    func contains(_ time: Double) -> Bool {
        time >= start && time <= end
    }

    /// 0 before and after the segment, rising to 1 while zooming in, 1 while held, falling to 0 while zooming out.
    func progress(at time: Double) -> Double {
        guard contains(time), duration > 0 else { return 0 }
        let ramp = rampDuration
        guard ramp > 0 else { return 1 }
        if time < start + ramp {
            return Easing.smooth((time - start) / ramp)
        }
        if time > end - ramp {
            return Easing.smooth((end - time) / ramp)
        }
        return 1
    }

    /// The zoom level at `time`: 1 outside the segment, `scale` while held.
    func scale(at time: Double) -> Double {
        pow(scale, progress(at: time))
    }

    /// Where the view looks at `time`: the first focus point until the first pan, then each focus point in turn.
    /// A pan to a focus point ends `panLead` before its time and takes at most `panDuration`.
    func center(at time: Double) -> CGPoint {
        guard var center = focus.first?.point else { return ZoomState.identity.center }
        for index in focus.indices.dropFirst() {
            let previous = focus[index - 1]
            let next = focus[index]
            let arrive = max(previous.time, next.time - Self.panLead)
            let depart = max(previous.time, arrive - Self.panDuration)
            if time <= depart {
                return center
            }
            if time < arrive, arrive > depart {
                let fraction = Easing.smooth((time - depart) / (arrive - depart))
                return CGPoint(
                    x: Easing.interpolate(center.x, next.point.x, fraction),
                    y: Easing.interpolate(center.y, next.point.y, fraction)
                )
            }
            center = next.point
        }
        return center
    }

    func state(at time: Double) -> ZoomState {
        ZoomState(scale: scale(at: time), center: center(at: time))
    }

    /// The focus point that the view shows at `time` (the one it is at, or panning towards), for editing.
    func focusIndex(at time: Double) -> Int {
        var index = 0
        for candidate in focus.indices.dropFirst() {
            let arrive = max(focus[candidate - 1].time, focus[candidate].time - Self.panLead)
            let depart = max(focus[candidate - 1].time, arrive - Self.panDuration)
            if time > depart {
                index = candidate
            }
        }
        return index
    }

    /// The segment moved by `offset` seconds.
    func shifted(by offset: Double) -> ZoomSegment {
        ZoomSegment(
            id: id,
            start: start + offset,
            end: end + offset,
            scale: scale,
            focus: focus.map { ZoomFocus(time: $0.time + offset, point: $0.point) }
        )
    }
}
