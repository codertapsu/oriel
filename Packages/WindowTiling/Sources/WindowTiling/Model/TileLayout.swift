import CoreGraphics

/// The frames of Window Tiling's layouts (PLAN §7.14), pure and table-tested on synthetic displays. Every rect is in
/// Accessibility's global coordinates (`DisplayGeometry`).
///
/// A layout is a share of the display's visible frame less the gap: neighbouring tiles are one gap apart, and so is a
/// tile from the screen's edges. Edges are rounded to whole points, so two halves meet exactly.
nonisolated enum TileLayout {
    /// Frames this close are the same: apps round sizes and positions to whole points.
    static let tolerance: CGFloat = 2

    /// Where `action` puts `window` on `display`. The halves take `TilingOptions.fraction(forStep:)` of the screen;
    /// maximize height and center keep part of `window`. Nil for the actions that are not a layout: the size steps,
    /// the display moves and restore.
    static func placement(
        for action: TilingAction,
        window: CGRect,
        on display: DisplayGeometry,
        step: Int = 0,
        options: TilingOptions
    ) -> TilePlacement? {
        let area = display.usableFrame(gap: options.gap)
        let gap = display.effectiveGap(options.gap)
        let share = TilingOptions.fraction(forStep: step)
        func tile(_ x: ClosedRange<CGFloat>, _ y: ClosedRange<CGFloat>) -> TilePlacement {
            region(x, y, of: area, gap: gap)
        }
        // Thirds run across a landscape screen and down a portrait one.
        func thirds(_ range: ClosedRange<CGFloat>) -> TilePlacement {
            display.isPortrait ? tile(0 ... 1, range) : tile(range, 0 ... 1)
        }
        switch action {
        case .leftHalf: return tile(0 ... share, 0 ... 1)
        case .rightHalf: return tile((1 - share) ... 1, 0 ... 1)
        case .topHalf: return tile(0 ... 1, 0 ... share)
        case .bottomHalf: return tile(0 ... 1, (1 - share) ... 1)
        case .topLeft: return tile(0 ... 0.5, 0 ... 0.5)
        case .topRight: return tile(0.5 ... 1, 0 ... 0.5)
        case .bottomLeft: return tile(0 ... 0.5, 0.5 ... 1)
        case .bottomRight: return tile(0.5 ... 1, 0.5 ... 1)
        case .firstThird: return thirds(0 ... 1 / 3)
        case .centerThird: return thirds(1 / 3 ... 2 / 3)
        case .lastThird: return thirds(2 / 3 ... 1)
        case .firstTwoThirds: return thirds(0 ... 2 / 3)
        case .lastTwoThirds: return thirds(1 / 3 ... 1)
        case .maximize: return tile(0 ... 1, 0 ... 1)
        case .almostMaximize: return almostMaximized(on: display, fraction: options.almostMaximizeFraction)
        case .maximizeHeight: return heightMaximized(window, in: area)
        case .center: return centered(window, in: area)
        case .smaller, .larger, .nextDisplay, .previousDisplay, .restore: return nil
        }
    }

    /// The part of `area` between the fractions `x` of its width and `y` of its height, with half a gap at each inner
    /// edge. The anchors keep the edges the region shares with the screen.
    static func region(_ x: ClosedRange<CGFloat>, _ y: ClosedRange<CGFloat>, of area: CGRect, gap: CGFloat) -> TilePlacement {
        let (minX, maxX) = edges(x, start: area.minX, length: area.width, gap: gap)
        let (minY, maxY) = edges(y, start: area.minY, length: area.height, gap: gap)
        return TilePlacement(
            frame: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
            horizontal: anchor(of: x),
            vertical: anchor(of: y)
        )
    }

    /// Centered, at `fraction` of the visible frame's width and height. The gap does not apply.
    static func almostMaximized(on display: DisplayGeometry, fraction: CGFloat) -> TilePlacement {
        let visible = display.visibleFrame
        let width = (visible.width * fraction).rounded()
        let height = (visible.height * fraction).rounded()
        let frame = CGRect(x: (visible.midX - width / 2).rounded(), y: (visible.midY - height / 2).rounded(), width: width, height: height)
        return TilePlacement(frame: frame)
    }

    /// The full height of `area`, keeping the window's width and left edge (moved in if it hangs over a side).
    static func heightMaximized(_ window: CGRect, in area: CGRect) -> TilePlacement {
        let width = min(window.width, area.width)
        let x = clamp(window.minX, lower: area.minX, upper: area.maxX - width).rounded()
        return TilePlacement(frame: CGRect(x: x, y: area.minY, width: width, height: area.height), horizontal: .start, vertical: .center)
    }

    /// The window's size, no larger than `area`, in its middle.
    static func centered(_ window: CGRect, in area: CGRect) -> TilePlacement {
        let width = min(window.width, area.width)
        let height = min(window.height, area.height)
        let frame = CGRect(x: (area.midX - width / 2).rounded(), y: (area.midY - height / 2).rounded(), width: width, height: height)
        return TilePlacement(frame: frame)
    }

    /// Whether two frames are the same within `tolerance`.
    static func isSame(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        upper < lower ? lower : min(max(value, lower), upper)
    }

    /// The rounded edges of the part of a span between two fractions, half a gap in from each inner edge.
    private static func edges(_ range: ClosedRange<CGFloat>, start: CGFloat, length: CGFloat, gap: CGFloat) -> (CGFloat, CGFloat) {
        let lower = start + range.lowerBound * length + (range.lowerBound > 0 ? gap / 2 : 0)
        let upper = start + range.upperBound * length - (range.upperBound < 1 ? gap / 2 : 0)
        return (lower.rounded(), upper.rounded())
    }

    /// A region against the screen's start keeps its start, one against the end its end; one spanning the whole axis,
    /// or neither edge, stays centered on its target.
    private static func anchor(of range: ClosedRange<CGFloat>) -> TilePlacement.Anchor {
        switch (range.lowerBound <= 0, range.upperBound >= 1) {
        case (true, false): .start
        case (false, true): .end
        default: .center
        }
    }
}
