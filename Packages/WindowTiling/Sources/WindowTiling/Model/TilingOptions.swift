import CoreGraphics

/// The settings that shape Window Tiling's frames, read once per action (Settings → Window Tiling).
nonisolated struct TilingOptions: Sendable, Equatable {
    /// The sizes a half steps through when its shortcut is pressed again: ½, ⅔, ⅓, and round again.
    static let cycleFractions: [CGFloat] = [1 / 2, 2 / 3, 1 / 3]
    /// Make Smaller and Make Larger change a window's width and height by this share of the screen.
    static let resizeStep: CGFloat = 0.05
    /// Make Smaller stops before a window gets narrower or shorter than this share of the screen.
    static let minimumFraction: CGFloat = 0.25
    /// The gaps offered in Settings, in points.
    static let gapRange: ClosedRange<CGFloat> = 0 ... 32
    /// The sizes offered for Almost Maximize.
    static let almostMaximizeRange: ClosedRange<CGFloat> = 0.6 ... 0.95

    /// Points between neighbouring tiles, and between a tile and the edges of the screen.
    var gap: CGFloat
    /// Whether pressing a half again steps through ½, ⅔ and ⅓ of the screen.
    var cyclesSizes: Bool
    /// Almost Maximize's share of the screen's width and of its height.
    var almostMaximizeFraction: CGFloat

    /// Values outside the ranges Settings offers (a hand-edited or imported setting) are brought into them.
    init(gap: CGFloat = 0, cyclesSizes: Bool = true, almostMaximizeFraction: CGFloat = 0.9) {
        self.gap = min(max(gap, Self.gapRange.lowerBound), Self.gapRange.upperBound)
        self.cyclesSizes = cyclesSizes
        self.almostMaximizeFraction = min(
            max(almostMaximizeFraction, Self.almostMaximizeRange.lowerBound),
            Self.almostMaximizeRange.upperBound
        )
    }

    /// The share of the screen a half takes at cycle step `step`.
    static func fraction(forStep step: Int) -> CGFloat {
        cycleFractions[((step % cycleFractions.count) + cycleFractions.count) % cycleFractions.count]
    }
}
