import CoreGraphics

/// How the toolbar's one width control (1…20) maps to each kind's own measure, and back.
nonisolated enum ToolStyle {
    static let widthRange: ClosedRange<CGFloat> = 1 ... 20
    static let defaultWidth: CGFloat = 4

    static func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, widthRange.lowerBound), widthRange.upperBound)
    }

    /// A highlighter is much broader than a pen at the same setting.
    static func highlighterWidth(_ width: CGFloat) -> CGFloat {
        width * 4
    }

    static func fontSize(_ width: CGFloat) -> CGFloat {
        max(10, width * 5)
    }

    static func counterRadius(_ width: CGFloat) -> CGFloat {
        8 + width * 2
    }

    /// Blur radius and pixel-block size, in points.
    static func effectAmount(_ width: CGFloat) -> CGFloat {
        4 + width * 2
    }

    /// The width setting that would have produced `item`, to show the selected item's style in the toolbar.
    static func width(of item: AnnotationItem) -> CGFloat? {
        let width: CGFloat? = switch item {
        case let .arrow(arrow): arrow.width
        case let .line(line): line.width
        case let .rect(box), let .ellipse(box): box.width
        case let .freehand(path): path.width
        case let .highlighter(path): path.width / 4
        case let .text(text): text.fontSize / 5
        case let .counter(counter): (counter.radius - 8) / 2
        case let .blur(region), let .pixelate(region): (region.amount - 4) / 2
        case .spotlight: nil
        }
        return width.map(clampedWidth)
    }
}
