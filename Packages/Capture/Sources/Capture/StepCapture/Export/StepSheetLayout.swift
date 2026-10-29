import CoreGraphics

/// Where everything goes on the one tall PNG of a step sequence: the title, then each step's numbered header (badge,
/// heading, note) above its image. Points, top-left origin. Pure, so the export's size is unit-tested.
///
/// The sheet is as wide as the widest image needs, between 640 and 1,600 points; wider images are scaled down to fit
/// and none is scaled up.
nonisolated struct StepSheetLayout: Sendable, Equatable {
    struct Block: Sendable, Equatable {
        let badge: CGRect
        let heading: CGRect
        let note: CGRect?
        let image: CGRect
    }

    static let margin: CGFloat = 40
    static let badgeSize: CGFloat = 28
    static let textGap: CGFloat = 12
    static let noteGap: CGFloat = 4
    static let imageGap: CGFloat = 14
    static let stepGap: CGFloat = 44
    static let titleGap: CGFloat = 28
    static let widths: ClosedRange<CGFloat> = 640 ... 1600
    /// The PNG stays within these, so a long sequence cannot ask for gigabytes.
    static let maximumPixelHeight: CGFloat = 30000
    static let maximumPixels: CGFloat = 80_000_000

    let width: CGFloat
    let height: CGFloat
    let title: CGRect
    let blocks: [Block]

    /// The width the text of a step's header has on a sheet `width` points wide.
    static func textWidth(sheetWidth width: CGFloat) -> CGFloat {
        width - 2 * margin - badgeSize - textGap
    }

    /// The sheet's width for images of `sizes` (points).
    static func width(for sizes: [CGSize]) -> CGFloat {
        let widest = sizes.map(\.width).max() ?? 0
        return min(max((widest + 2 * margin).rounded(.up), widths.lowerBound), widths.upperBound)
    }

    /// - Parameters:
    ///   - width: from `width(for:)`.
    ///   - titleHeight: the title and its subtitle, set at the content width.
    ///   - imageSizes: each step's image in points.
    ///   - textHeights: each step's heading and note, set at `textWidth(sheetWidth:)`; 0 for no note.
    init(width: CGFloat, titleHeight: CGFloat, imageSizes: [CGSize], textHeights: [(heading: CGFloat, note: CGFloat)]) {
        let margin = Self.margin
        let content = width - 2 * margin
        let textX = margin + Self.badgeSize + Self.textGap
        let textWidth = Self.textWidth(sheetWidth: width)
        title = CGRect(x: margin, y: margin, width: content, height: titleHeight)
        var y = title.maxY + Self.titleGap
        var blocks: [Block] = []
        for (index, size) in imageSizes.enumerated() {
            let text = index < textHeights.count ? textHeights[index] : (heading: 0, note: 0)
            let badge = CGRect(x: margin, y: y, width: Self.badgeSize, height: Self.badgeSize)
            // A heading of one line sits level with the badge; a longer one starts at its top.
            let headingY = text.heading < Self.badgeSize ? y + ((Self.badgeSize - text.heading) / 2).rounded() : y
            let heading = CGRect(x: textX, y: headingY, width: textWidth, height: text.heading)
            let note = text.note > 0 ? CGRect(x: textX, y: heading.maxY + Self.noteGap, width: textWidth, height: text.note) : nil
            let headerBottom = max(badge.maxY, note?.maxY ?? heading.maxY)
            let fitted = Self.fit(size, width: content)
            let image = CGRect(
                x: (margin + (content - fitted.width) / 2).rounded(),
                y: headerBottom + Self.imageGap,
                width: fitted.width,
                height: fitted.height
            )
            blocks.append(Block(badge: badge, heading: heading, note: note, image: image))
            y = image.maxY + Self.stepGap
        }
        self.width = width
        self.blocks = blocks
        height = (blocks.isEmpty ? title.maxY : y - Self.stepGap) + margin
    }

    /// Pixels per point for the PNG: `preferred` (the steps' own scale), lowered when the sheet would be taller than
    /// `maximumPixelHeight` or larger than `maximumPixels`.
    func scale(preferred: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return preferred }
        return min(preferred, Self.maximumPixelHeight / height, (Self.maximumPixels / (width * height)).squareRoot())
    }

    /// The PNG's size in pixels at `scale`.
    func pixelSize(scale: CGFloat) -> CGSize {
        CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }

    /// `size` scaled down to `width` when wider, keeping its shape; never up.
    static func fit(_ size: CGSize, width: CGFloat) -> CGSize {
        guard size.width > width, size.width > 0 else { return CGSize(width: size.width.rounded(), height: size.height.rounded()) }
        let factor = width / size.width
        return CGSize(width: width.rounded(), height: (size.height * factor).rounded())
    }
}
