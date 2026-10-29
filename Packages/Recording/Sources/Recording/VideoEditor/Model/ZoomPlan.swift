/// Every zoom of a movie, as the compositor reads it frame by frame (PLAN §17). Pure and immutable, so the
/// compositor can read it from AVFoundation's rendering threads.
nonisolated struct ZoomPlan: Equatable, Sendable {
    /// No zoom at all.
    static let none = ZoomPlan(segments: [])

    /// In start order, without empty segments.
    let segments: [ZoomSegment]

    init(segments: [ZoomSegment]) {
        self.segments = segments.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
    }

    var isEmpty: Bool {
        segments.isEmpty
    }

    /// The zoom at `time`. The editor keeps segments from overlapping; if they did, the one zoomed in further wins,
    /// so the result still changes smoothly.
    func state(at time: Double) -> ZoomState {
        var best = ZoomState.identity
        for segment in segments {
            if segment.start > time {
                break
            }
            guard segment.contains(time) else { continue }
            let state = segment.state(at: time)
            if state.scale > best.scale {
                best = state
            }
        }
        return best
    }

    /// The plan for a copy of the movie that keeps only `range`: segments outside it are dropped, the others move
    /// so that `range.lowerBound` becomes 0. A segment cut by the range keeps its shape; the copy starts or ends
    /// part of the way through it.
    func trimmed(to range: ClosedRange<Double>) -> ZoomPlan {
        ZoomPlan(segments: segments.filter { $0.end > range.lowerBound && $0.start < range.upperBound }
            .map { $0.shifted(by: -range.lowerBound) })
    }
}
