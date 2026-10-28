import CoreGraphics

/// Where the overlay, its toolbar and the side panel go, in Cocoa screen coordinates (bottom-left origin). Pure, so it
/// is testable without screens.
enum OverlayPlacement {
    /// The overlay covers the captured area. A capture without a screen area (an imported image) is centred on the
    /// screen instead, scaled down to fit 90 % of it.
    static func overlayFrame(captureRect: CGRect, pointSize: CGSize, visibleFrame: CGRect) -> CGRect {
        guard captureRect.width <= 0 || captureRect.height <= 0 else { return captureRect }
        let maximum = CGSize(width: visibleFrame.width * 0.9, height: visibleFrame.height * 0.9)
        let factor = min(1, maximum.width / max(1, pointSize.width), maximum.height / max(1, pointSize.height))
        let size = CGSize(width: (pointSize.width * factor).rounded(), height: (pointSize.height * factor).rounded())
        return CGRect(
            x: (visibleFrame.midX - size.width / 2).rounded(),
            y: (visibleFrame.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }

    /// Above the overlay when the screen has room, else below it, else just inside its top edge; aligned with its left
    /// edge and kept on the screen.
    static func toolbarFrame(size: CGSize, overlay: CGRect, visibleFrame: CGRect, gap: CGFloat = 8) -> CGRect {
        let y: CGFloat = if overlay.maxY + gap + size.height <= visibleFrame.maxY {
            overlay.maxY + gap
        } else if overlay.minY - gap - size.height >= visibleFrame.minY {
            overlay.minY - gap - size.height
        } else {
            min(overlay.maxY, visibleFrame.maxY) - gap - size.height
        }
        let x = min(max(overlay.minX, visibleFrame.minX + gap), visibleFrame.maxX - gap - size.width)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Beside the overlay: to the right when there is room, else to the left, else at the screen's right edge. Top
    /// aligned with the overlay and kept on the screen.
    static func sidePanelFrame(size: CGSize, overlay: CGRect, visibleFrame: CGRect, gap: CGFloat = 12) -> CGRect {
        let height = min(size.height, visibleFrame.height - 2 * gap)
        let x: CGFloat = if overlay.maxX + gap + size.width <= visibleFrame.maxX {
            overlay.maxX + gap
        } else if overlay.minX - gap - size.width >= visibleFrame.minX {
            overlay.minX - gap - size.width
        } else {
            visibleFrame.maxX - gap - size.width
        }
        let top = min(overlay.maxY, visibleFrame.maxY - gap)
        let y = max(visibleFrame.minY + gap, top - height)
        return CGRect(x: x, y: y, width: size.width, height: height)
    }
}
