import Foundation

/// The video editor's timeline geometry (PLAN §17): which stretch of the movie is visible across how many points,
/// and how zooming and scrolling change that. Pure.
///
/// Fitted, the whole movie fills the width. Zooming in narrows the visible stretch around an anchor, down to
/// `minimumVisibleDuration`; scrolling moves it, never past the movie's ends.
nonisolated struct TimelineMapping: Equatable, Sendable {
    /// The shortest stretch the timeline zooms in to.
    static let minimumVisibleDuration = 1.0

    /// The movie's length in seconds.
    private(set) var duration: Double
    /// The timeline's width in points.
    private(set) var width: Double
    /// The first visible second.
    private(set) var visibleStart: Double = 0
    /// How many seconds are visible.
    private(set) var visibleDuration: Double

    init(duration: Double, width: Double) {
        self.duration = max(duration, 0)
        self.width = max(width, 1)
        visibleDuration = max(duration, 0)
    }

    var visibleEnd: Double {
        visibleStart + visibleDuration
    }

    /// Whether the whole movie is visible.
    var isFitted: Bool {
        visibleDuration >= duration - 0.0001
    }

    /// Points per second.
    var pointsPerSecond: Double {
        visibleDuration > 0 ? width / visibleDuration : 0
    }

    /// The x position of `time`, 0 at the timeline's left edge.
    func x(for time: Double) -> Double {
        (time - visibleStart) * pointsPerSecond
    }

    /// The time at `x`, within the movie.
    func time(for x: Double) -> Double {
        guard pointsPerSecond > 0 else { return 0 }
        return min(max(visibleStart + x / pointsPerSecond, 0), duration)
    }

    /// The zoom slider's position: 0 fitted, 1 zoomed all the way in, logarithmic in between.
    var zoomFraction: Double {
        let range = maximumZoom
        guard range > 1 else { return 0 }
        return min(max(log(duration / visibleDuration) / log(range), 0), 1)
    }

    /// How many times the timeline can be zoomed in.
    private var maximumZoom: Double {
        duration / min(Self.minimumVisibleDuration, max(duration, 0.0001))
    }

    mutating func setWidth(_ width: Double) {
        self.width = max(width, 1)
    }

    mutating func setDuration(_ duration: Double) {
        self.duration = max(duration, 0)
        fit()
    }

    /// Shows the whole movie.
    mutating func fit() {
        visibleStart = 0
        visibleDuration = duration
    }

    /// Zooms in (`factor` > 1) or out around `anchorX`, which keeps showing the same time.
    mutating func zoom(by factor: Double, around anchorX: Double) {
        guard factor.isFinite, factor > 0, duration > 0 else { return }
        let anchorTime = visibleStart + anchorX / max(pointsPerSecond, .leastNonzeroMagnitude)
        let minimum = min(Self.minimumVisibleDuration, duration)
        visibleDuration = min(max(visibleDuration / factor, minimum), duration)
        visibleStart = anchorTime - anchorX / pointsPerSecond
        clampStart()
    }

    /// Sets the zoom from the slider (see `zoomFraction`), keeping the middle of the visible stretch.
    mutating func setZoomFraction(_ fraction: Double) {
        guard duration > 0 else { return }
        let middle = visibleStart + visibleDuration / 2
        let fraction = min(max(fraction, 0), 1)
        visibleDuration = duration / pow(maximumZoom, fraction)
        visibleStart = middle - visibleDuration / 2
        clampStart()
    }

    /// Moves the visible stretch by `points`; positive moves later.
    mutating func scroll(by points: Double) {
        guard pointsPerSecond > 0 else { return }
        visibleStart += points / pointsPerSecond
        clampStart()
    }

    /// The ruler's step between labelled ticks: the shortest common step at least `minimumSpacing` points apart.
    func tickInterval(minimumSpacing: Double = 72) -> Double {
        let steps: [Double] = [0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200]
        return steps.first { $0 * pointsPerSecond >= minimumSpacing } ?? steps[steps.count - 1]
    }

    /// Scrolls, if needed, so that `time` is visible with a margin, as during playback.
    mutating func reveal(_ time: Double) {
        guard !isFitted else { return }
        let margin = visibleDuration * 0.05
        if time < visibleStart + margin || time > visibleEnd - margin {
            visibleStart = time - visibleDuration * 0.1
            clampStart()
        }
    }

    private mutating func clampStart() {
        visibleStart = min(max(visibleStart, 0), max(duration - visibleDuration, 0))
    }
}
