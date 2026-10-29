/// The easing curves of the video editor's zooms and pans. Pure.
nonisolated enum Easing {
    /// Ken Perlin's smootherstep, 6x⁵ − 15x⁴ + 10x³: starts and ends at rest, with no jolt in acceleration either,
    /// so a zoom or pan glides in and out. Inputs outside 0…1 are clamped.
    static func smooth(_ x: Double) -> Double {
        guard x.isFinite else { return 0 }
        let clamped = min(max(x, 0), 1)
        return clamped * clamped * clamped * (clamped * (clamped * 6 - 15) + 10)
    }

    /// The point `fraction` of the way from `start` to `end`.
    static func interpolate(_ start: Double, _ end: Double, _ fraction: Double) -> Double {
        start + (end - start) * fraction
    }
}
