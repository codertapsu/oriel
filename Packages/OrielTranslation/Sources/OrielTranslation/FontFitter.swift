import AppKit

/// Finds the largest font size at which a translation fits its box (PLAN §7.7.6): a binary search between 6 pt and
/// the original line height, measured with `boundingRect(with:options:)` and the same options the overlay draws with.
/// A size is only ever returned as fitting after it was measured to fit, so text drawn at a fitting size never
/// overflows its box.
enum FontFitter {
    static let minimumSize: CGFloat = 6
    /// Search precision in points.
    private static let step: CGFloat = 0.25
    /// Rounding slack when comparing measured and available sizes.
    private static let slack: CGFloat = 0.5

    struct Fit: Equatable {
        let fontSize: CGFloat
        /// The measured size of the text at `fontSize` within the box's width.
        let textSize: CGSize
        /// False when even the minimum size is too tall; the overlay then grows the box downward.
        let fits: Bool
    }

    static let drawingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    static func fit(_ text: String, in box: CGSize, maximumSize: CGFloat, rightToLeft: Bool = false) -> Fit {
        let maximum = max(minimumSize, maximumSize)
        func fits(_ size: CGSize) -> Bool {
            size.height <= box.height + slack && size.width <= box.width + slack
        }
        let atMaximum = measure(text, fontSize: maximum, width: box.width, rightToLeft: rightToLeft)
        if fits(atMaximum) {
            return Fit(fontSize: maximum, textSize: atMaximum, fits: true)
        }
        let atMinimum = measure(text, fontSize: minimumSize, width: box.width, rightToLeft: rightToLeft)
        guard fits(atMinimum) else {
            return Fit(fontSize: minimumSize, textSize: atMinimum, fits: false)
        }
        var low = minimumSize
        var high = maximum
        var best = Fit(fontSize: minimumSize, textSize: atMinimum, fits: true)
        while high - low > step {
            let middle = (low + high) / 2
            let size = measure(text, fontSize: middle, width: box.width, rightToLeft: rightToLeft)
            if fits(size) {
                low = middle
                best = Fit(fontSize: middle, textSize: size, fits: true)
            } else {
                high = middle
            }
        }
        return best
    }

    static func measure(_ text: String, fontSize: CGFloat, width: CGFloat, rightToLeft: Bool = false) -> CGSize {
        let string = NSAttributedString(string: text, attributes: attributes(fontSize: fontSize, color: .black, rightToLeft: rightToLeft))
        let rect = string.boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude), options: drawingOptions, context: nil
        )
        return CGSize(width: rect.width.rounded(.up), height: rect.height.rounded(.up))
    }

    static func attributes(fontSize: CGFloat, color: NSColor, rightToLeft: Bool) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .natural
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        return [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    }
}
