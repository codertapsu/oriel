import CoreGraphics

/// What to do when a window does not end up where it was sent, and where a restored window may go. Pure.
nonisolated enum TileFitting {
    /// A strip this tall at the top of a window is its title bar: a window whose strip shows on a display can be
    /// dragged back by hand.
    static let titleBarHeight: CGFloat = 24

    /// Where a window that came out `size` instead of the placement's size goes: against the target's edges the anchors
    /// name, then onto `display`'s visible frame. A window larger than the visible frame keeps its top left corner on
    /// it, so its title bar stays in reach.
    static func fitted(_ placement: TilePlacement, size: CGSize, on display: DisplayGeometry) -> CGRect {
        let target = placement.frame
        let bounds = display.visibleFrame
        let x = fit(target.minX, target.width, size.width, anchor: placement.horizontal, within: bounds.minX, bounds.width)
        let y = fit(target.minY, target.height, size.height, anchor: placement.vertical, within: bounds.minY, bounds.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// `frame` when its title bar shows on one of `displays`; otherwise centered on `fallback`'s visible frame, and
    /// shrunk to it if need be. A restored window must never land where it cannot be reached, as it would after the
    /// display it was on has been unplugged.
    static func reachable(_ frame: CGRect, displays: [DisplayGeometry], fallback: DisplayGeometry) -> CGRect {
        let titleBar = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: min(frame.height, titleBarHeight))
        let shows = displays.contains { display in
            let overlap = display.visibleFrame.intersection(titleBar)
            return !overlap.isNull && overlap.width >= min(40, frame.width) && overlap.height >= min(8, titleBar.height)
        }
        if shows {
            return frame
        }
        let bounds = fallback.visibleFrame
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        return CGRect(x: (bounds.midX - width / 2).rounded(), y: (bounds.midY - height / 2).rounded(), width: width, height: height)
    }

    /// Along one axis: the start that lines a window of `actual` length up with the target, kept inside the bounds.
    private static func fit(
        _ start: CGFloat,
        _ length: CGFloat,
        _ actual: CGFloat,
        anchor: TilePlacement.Anchor,
        within boundsStart: CGFloat,
        _ boundsLength: CGFloat
    ) -> CGFloat {
        guard actual < boundsLength else { return boundsStart }
        let wanted = switch anchor {
        case .start: start
        case .center: start + (length - actual) / 2
        case .end: start + length - actual
        }
        return TileLayout.clamp(wanted, lower: boundsStart, upper: boundsStart + boundsLength - actual).rounded()
    }
}
