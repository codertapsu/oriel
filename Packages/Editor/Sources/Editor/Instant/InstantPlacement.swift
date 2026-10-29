import CoreGraphics
import OrielCore

/// Where Instant Capture's panel and toolbar go (PLAN §17). The panel sits exactly over the selection, so the capture
/// shows at 1:1 where it was taken and drawing on it looks like drawing on the screen; a thin outline just outside
/// marks its edge. The toolbar goes below the selection, right-aligned with it, or above it when there is no room
/// below, or inside along its bottom edge when the selection fills the screen; it always stays on the screen.
///
/// Pure: the screens are passed in, so every layout, negative origins and mixed scales included, is unit-tested.
nonisolated struct InstantPlacement: Equatable, Sendable {
    /// A display in Cocoa coordinates (origin at the bottom-left of the primary display, y up).
    struct Screen: Equatable, Sendable {
        var frame: CGRect
        /// The frame without the menu bar and the Dock.
        var visibleFrame: CGRect
        /// Pixels per point.
        var scale: CGFloat
    }

    enum ToolbarPosition: Equatable, Sendable {
        case below, above, inside
    }

    /// The panel's frame (Cocoa): the selection grown by `outlineMargin` on every side.
    let panelFrame: CGRect
    /// Exactly the selection (Cocoa), aligned to the display's pixels: where the image is shown.
    let canvasFrame: CGRect
    let toolbarFrame: CGRect
    let toolbarPosition: ToolbarPosition
    /// The display the selection is on (an index into the screens given), and its scale.
    let screenIndex: Int
    let scale: CGFloat

    /// Room for the outline around the image.
    static let outlineMargin: CGFloat = 2
    /// Between the selection and the toolbar.
    static let gap: CGFloat = 8
    /// Between the toolbar and the screen's edge.
    static let edgeMargin: CGFloat = 6

    /// - Parameters:
    ///   - selection: the selection in global CoreGraphics points (top-left origin), as `selectRegion` returns it.
    ///   - screens: the displays, primary first.
    ///   - primaryHeight: the primary display's height, which flips between the two coordinate systems.
    ///   - toolbarSize: the toolbar's fitting size.
    /// - Returns: nil without screens or with an empty selection.
    static func place(selection: CGRect, screens: [Screen], primaryHeight: CGFloat, toolbarSize: CGSize) -> InstantPlacement? {
        guard !screens.isEmpty, !selection.isNull, selection.width > 0, selection.height > 0 else { return nil }
        let cocoa = ScreenGeometry.cocoaRect(fromCG: selection.standardized, primaryHeight: primaryHeight)
        let index = ScreenGeometry.bestDisplay(for: cocoa, among: screens.map(\.frame)) ?? 0
        let screen = screens[index]
        let canvas = aligned(cocoa, to: screen)
        let visible = screen.visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        let width = toolbarSize.width, height = toolbarSize.height
        var x = canvas.maxX - width
        x = width >= visible.width ? visible.minX : min(max(x, visible.minX), visible.maxX - width)
        let position: ToolbarPosition
        var y: CGFloat
        if canvas.minY - outlineMargin - gap - height >= visible.minY {
            position = .below
            y = canvas.minY - outlineMargin - gap - height
        } else if canvas.maxY + outlineMargin + gap + height <= visible.maxY {
            position = .above
            y = canvas.maxY + outlineMargin + gap
        } else {
            position = .inside
            y = min(max(canvas.minY + gap, visible.minY), visible.maxY - height)
        }
        y = y.rounded()
        x = x.rounded()
        return InstantPlacement(
            panelFrame: canvas.insetBy(dx: -outlineMargin, dy: -outlineMargin),
            canvasFrame: canvas,
            toolbarFrame: CGRect(x: x, y: y, width: width, height: height),
            toolbarPosition: position,
            screenIndex: index,
            scale: screen.scale
        )
    }

    /// `rect` snapped to `screen`'s pixel grid, which starts at the screen's own origin.
    private static func aligned(_ rect: CGRect, to screen: Screen) -> CGRect {
        let origin = screen.frame.origin
        let local = rect.offsetBy(dx: -origin.x, dy: -origin.y)
        return Geometry.pixelAligned(local, scale: max(screen.scale, 1)).offsetBy(dx: origin.x, dy: origin.y)
    }
}
