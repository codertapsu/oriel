/// What Auto Zoom makes of a recording's clicks: how far it zooms and how long it stays (PLAN §17).
nonisolated struct AutoZoomSettings: Equatable, Sendable {
    /// How long the view stays zoomed after a click, at least and at most.
    static let holds: ClosedRange<Double> = 0.5 ... 5
    /// The zoom-in finishes this long before the click, so the click is seen up close.
    static let lead = 0.2
    /// A zoom-out and the next zoom-in closer than this become one segment that pans instead.
    static let mergeGap = 0.75
    /// A click inside this share of the zoomed view (around its middle) does not move the view.
    static let comfortZone = 0.6

    /// The zoom level, within `ZoomSegment.scales`.
    let level: Double
    /// Seconds the view stays zoomed after the last click of a group, within `holds`.
    let hold: Double

    init(level: Double = 2, hold: Double = 1.5) {
        self.level = min(max(level.isFinite ? level : 2, ZoomSegment.scales.lowerBound), ZoomSegment.scales.upperBound)
        self.hold = min(max(hold.isFinite ? hold : 1.5, Self.holds.lowerBound), Self.holds.upperBound)
    }

    /// Clicks closer together than this share one segment: the zoom-out after one would end less than `mergeGap`
    /// before the zoom-in for the next.
    var groupingInterval: Double {
        hold + 2 * ZoomSegment.transition + Self.lead + Self.mergeGap
    }
}
