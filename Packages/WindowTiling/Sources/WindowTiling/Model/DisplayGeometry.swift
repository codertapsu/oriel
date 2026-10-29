import CoreGraphics
import OrielCore

/// One display as Window Tiling sees it: its whole frame and the part windows may use, without the menu bar and the
/// Dock (`NSScreen.visibleFrame`). Both are in Accessibility's global coordinates, the ones `kAXPositionAttribute`
/// uses: points, with the origin at the top left of the primary display and y going down.
nonisolated struct DisplayGeometry: Sendable, Equatable {
    /// The `CGDirectDisplayID`.
    var id: UInt32
    var frame: CGRect
    var visibleFrame: CGRect

    init(id: UInt32, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    /// From an `NSScreen`'s `frame` and `visibleFrame`, whose origin is the primary display's bottom left with y going
    /// up. `primaryHeight` is the primary display's height, which turns one system into the other.
    init(id: UInt32, cocoaFrame: CGRect, cocoaVisibleFrame: CGRect, primaryHeight: CGFloat) {
        self.init(
            id: id,
            frame: ScreenGeometry.cgRect(fromCocoa: cocoaFrame, primaryHeight: primaryHeight),
            visibleFrame: ScreenGeometry.cgRect(fromCocoa: cocoaVisibleFrame, primaryHeight: primaryHeight)
        )
    }

    /// Taller than wide: thirds then stack from top to bottom.
    var isPortrait: Bool {
        visibleFrame.height > visibleFrame.width
    }

    /// The gap that fits: at most a quarter of the visible frame's shorter side, so tiles never collapse.
    func effectiveGap(_ gap: CGFloat) -> CGFloat {
        min(max(gap, 0), (min(visibleFrame.width, visibleFrame.height) / 4).rounded(.down))
    }

    /// The visible frame less the gap along every edge: where tiles go.
    func usableFrame(gap: CGFloat) -> CGRect {
        let inset = effectiveGap(gap)
        return visibleFrame.insetBy(dx: inset, dy: inset)
    }
}
