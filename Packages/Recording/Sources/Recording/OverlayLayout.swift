import CoreGraphics

/// Where the control bar and the recorded overlays go, in Cocoa screen coordinates (y up). Pure.
nonisolated enum OverlayLayout {
    /// Space between the control bar and the recorded area or the screen's edge.
    static let margin: CGFloat = 12
    /// The camera bubble's diameter when the recorded area is large enough.
    static let cameraDiameter: CGFloat = 180

    /// Centred below the recorded area when the screen has room, else above it, else inside it near the bottom.
    /// The bar is excluded from the recording, so covering part of the area only hides it from the user.
    static func controlBarFrame(size: CGSize, captureRect: CGRect, visibleFrame: CGRect) -> CGRect {
        let x = clamp(
            captureRect.midX - size.width / 2,
            lower: visibleFrame.minX + margin,
            upper: visibleFrame.maxX - size.width - margin
        )
        let below = captureRect.minY - margin - size.height
        if below >= visibleFrame.minY + margin {
            return CGRect(x: x, y: below, width: size.width, height: size.height)
        }
        let above = captureRect.maxY + margin
        if above + size.height <= visibleFrame.maxY - margin {
            return CGRect(x: x, y: above, width: size.width, height: size.height)
        }
        let inside = max(captureRect.minY, visibleFrame.minY) + 2 * margin
        return CGRect(x: x, y: inside, width: size.width, height: size.height)
    }

    /// A circle in the recorded area's bottom-left corner, at most a third of the area's shorter side.
    static func cameraBubbleFrame(captureRect: CGRect) -> CGRect {
        let shorter = min(captureRect.width, captureRect.height)
        let diameter = max(min(cameraDiameter, shorter / 3), 1)
        let inset = min(24, shorter / 12)
        return CGRect(x: captureRect.minX + inset, y: captureRect.minY + inset, width: diameter, height: diameter)
    }

    /// Centred horizontally near the bottom of the recorded area.
    static func keystrokeFrame(size: CGSize, captureRect: CGRect) -> CGRect {
        let bottom = min(captureRect.height * 0.12, 72)
        return CGRect(
            x: captureRect.midX - size.width / 2,
            y: captureRect.minY + bottom,
            width: size.width,
            height: size.height
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        max(lower, min(value, upper))
    }
}
