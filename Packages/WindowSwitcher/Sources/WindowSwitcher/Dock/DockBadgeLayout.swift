import CoreGraphics

/// Where a window count sits on a Dock icon (PLAN §7.1.12): a capsule on the icon's lower corner away from the screen's
/// edge (lower right for a Dock at the bottom or on the left, lower left for one on the right), clear of the app's own
/// badge at the upper right and of the running indicator, and kept inside the icon's frame so it never leaves the
/// screen. Pure; CoreGraphics coordinates (y down).
nonisolated enum DockBadgeLayout {
    /// Apps with one window get no count: the badge is for apps with several.
    static let minimumCount = 2

    /// The text of a count: "2" to "99", then "99+"; nil below `minimumCount`.
    static func text(for count: Int) -> String? {
        guard count >= minimumCount else { return nil }
        return count > 99 ? "99+" : String(count)
    }

    /// The icon's square inside an item's frame, which the Dock pads on the running indicator's side.
    static func iconRect(of frame: CGRect) -> CGRect {
        let side = min(frame.width, frame.height)
        return CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side)
    }

    /// The capsule's height for an icon of `side` points: a little over a third of it, from 13 to 20 points.
    static func height(forIcon side: CGFloat) -> CGFloat {
        min(20, max(13, (side * 0.38).rounded()))
    }

    /// The capsule's frame for an item's frame, the Dock's edge, and the width of its text in points.
    static func frame(itemFrame: CGRect, edge: DockLayout.Edge, textWidth: CGFloat) -> CGRect {
        let icon = iconRect(of: itemFrame)
        let height = height(forIcon: icon.height)
        let width = max(height, (textWidth + height * 0.6).rounded(.up))
        let overhang = (height * 0.25).rounded()
        var x = edge == .right ? icon.minX - overhang : icon.maxX + overhang - width
        var y = icon.maxY + overhang - height
        x = max(min(x, itemFrame.maxX - width), itemFrame.minX)
        y = max(min(y, itemFrame.maxY - height), itemFrame.minY)
        return CGRect(x: x.rounded(), y: y.rounded(), width: width, height: height)
    }
}
