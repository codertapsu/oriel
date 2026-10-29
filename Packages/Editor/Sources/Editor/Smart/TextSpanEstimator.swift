import CoreGraphics
import CoreText
import Foundation

/// Where part of a recognized line sits inside the line's box. OCR gives boxes for whole lines only, so the part's
/// place is estimated from how wide the text before it and the part itself are. Screens show proportional text
/// (UI) and monospaced text (code, terminals), whose widths differ, so the estimate covers both: the union of a
/// proportional estimate (measured with the system font) and a monospaced one (character counts). The screen's
/// font is never quite the one measured with, and the error adds up along the line, so each edge also gets
/// `slack` of its distance from the line's start, then the padding: a little too much is hidden, never too little.
nonisolated enum TextSpanEstimator {
    /// How far off, as a share of the distance from the line's start, a width measured in another font can be.
    static let slack: CGFloat = 0.06

    /// The box of UTF-16 range `location ..< location + length` of `text` in `lineBox` (image space), padded by
    /// `padding` points, and never wider than the padded line.
    static func box(location: Int, length: Int, in text: String, lineBox: CGRect, padding: CGFloat) -> CGRect {
        let string = text as NSString
        let total = string.length
        let padded = lineBox.insetBy(dx: -padding, dy: -padding)
        guard total > 0, length > 0, location >= 0, location + length <= total else { return padded }
        let proportional = proportionalSpan(location: location, length: length, in: string)
        let monospaced = (Double(location) / Double(total), Double(location + length) / Double(total))
        let start = lineBox.width * CGFloat(min(proportional.0, monospaced.0)) * (1 - slack)
        let end = lineBox.width * CGFloat(max(proportional.1, monospaced.1)) * (1 + slack)
        let span = CGRect(x: lineBox.minX + start, y: lineBox.minY, width: end - start, height: lineBox.height)
        return span.insetBy(dx: -padding, dy: -padding).intersection(padded)
    }

    /// The fractions of the line's width where the range starts and ends, measured with the system font.
    private static func proportionalSpan(location: Int, length: Int, in string: NSString) -> (Double, Double) {
        let total = width(of: string as String)
        guard total > 0 else { return (Double(location) / Double(string.length), Double(location + length) / Double(string.length)) }
        let before = width(of: string.substring(to: location))
        let through = width(of: string.substring(to: location + length))
        return (min(1, before / total), min(1, through / total))
    }

    private static func width(of text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let font = CTFontCreateUIFontForLanguage(.system, 13, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 13, nil)
        let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}
