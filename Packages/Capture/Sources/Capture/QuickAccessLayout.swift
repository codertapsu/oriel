import CoreGraphics

/// Where the Quick Access cards go: stacked from a corner of the screen's visible frame, newest nearest the corner
/// (PLAN §7.2, item 6). Pure, in Cocoa coordinates (bottom-left origin), so the stacking is unit-tested.
nonisolated enum QuickAccessLayout {
    /// One frame per card that fits, index 0 (the newest) in the corner. Cards that do not fit get no frame.
    static func frames(
        count: Int,
        cardSize: CGSize,
        in visibleFrame: CGRect,
        corner: ScreenCorner,
        margin: CGFloat = 16,
        spacing: CGFloat = 10
    ) -> [CGRect] {
        let fitting = min(count, capacity(cardHeight: cardSize.height, in: visibleFrame, margin: margin, spacing: spacing))
        guard fitting > 0 else { return [] }
        let x = corner.isRight ? visibleFrame.maxX - margin - cardSize.width : visibleFrame.minX + margin
        return (0 ..< fitting).map { index in
            let step = CGFloat(index) * (cardSize.height + spacing)
            let y = corner.isBottom
                ? visibleFrame.minY + margin + step
                : visibleFrame.maxY - margin - cardSize.height - step
            return CGRect(x: x, y: y, width: cardSize.width, height: cardSize.height)
        }
    }

    /// How many cards fit in one column of `visibleFrame`; at least one.
    static func capacity(cardHeight: CGFloat, in visibleFrame: CGRect, margin: CGFloat, spacing: CGFloat) -> Int {
        guard cardHeight > 0 else { return 0 }
        let available = visibleFrame.height - 2 * margin + spacing
        return max(1, Int((available / (cardHeight + spacing)).rounded(.down)))
    }
}
