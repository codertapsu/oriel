import CoreGraphics

/// Where Translate Under Cursor reads and where its tooltip goes, in global points with a top-left origin. Pure.
enum CursorGeometry {
    /// About three lines of ordinary text on either side of the pointer, and room for a line to the left and right.
    static let captureSize = CGSize(width: 600, height: 120)
    /// Space between the text and the tooltip, and between the tooltip and the screen's edge.
    static let gap: CGFloat = 8

    /// `size` centred on `point`, moved (not shrunk) to stay on `screen`.
    static func captureRect(around point: CGPoint, on screen: CGRect, size: CGSize = captureSize) -> CGRect {
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        let x = min(max(point.x - width / 2, screen.minX), screen.maxX - width)
        let y = min(max(point.y - height / 2, screen.minY), screen.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height).integral.intersection(screen)
    }

    /// The tooltip's frame: below the text it translates, starting a little left of the pointer, so the text stays
    /// readable; above the text when there is no room below; and over the text's lower part when it fills the screen.
    static func tooltipFrame(size: CGSize, region: CGRect, pointer: CGPoint, visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width - 2 * gap)
        let height = min(size.height, visible.height - 2 * gap)
        let x = min(max(pointer.x - 24, visible.minX + gap), visible.maxX - gap - width)
        let below = region.maxY + gap
        let above = region.minY - gap - height
        let y: CGFloat = if below + height <= visible.maxY - gap {
            below
        } else if above >= visible.minY + gap {
            above
        } else {
            min(max(pointer.y + 24, visible.minY + gap), visible.maxY - gap - height)
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
