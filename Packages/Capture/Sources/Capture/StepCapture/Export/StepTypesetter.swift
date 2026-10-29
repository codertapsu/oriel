import CoreGraphics
import CoreText
import Foundation

/// Text for the PNG and PDF exports, set with Core Text so it works off the main thread and stays real, selectable
/// text in a PDF. Layout is done with a top-left origin; drawing converts to the context's bottom-left one.
nonisolated enum StepTypesetter {
    static let primary = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    static let secondary = CGColor(srgbRed: 0.42, green: 0.42, blue: 0.45, alpha: 1)
    static let separator = CGColor(srgbRed: 0.85, green: 0.85, blue: 0.87, alpha: 1)

    /// The system font, regular or semibold.
    static func font(size: CGFloat, bold: Bool = false) -> CTFont {
        CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    static func text(_ string: String, font: CTFont, color: CGColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
    }

    /// The height `text` needs at `width`; zero when it is empty.
    static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        guard text.length > 0, width > 0 else { return 0 }
        let setter = CTFramesetterCreateWithAttributedString(text)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            setter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )
        return size.height.rounded(.up)
    }

    /// Draws `text` into `rect` (top-left origin) of a canvas `canvasHeight` tall; lines that do not fit are left out.
    static func draw(_ text: NSAttributedString, in rect: CGRect, canvasHeight: CGFloat, context: CGContext) {
        guard text.length > 0, rect.width > 0, rect.height > 0 else { return }
        let setter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: flipped(rect, canvasHeight: canvasHeight), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    /// One line of `text` centred on `center` (top-left origin), for the numbers in the badges.
    static func drawCentred(_ text: NSAttributedString, at center: CGPoint, canvasHeight: CGFloat, context: CGContext) {
        let line = CTLineCreateWithAttributedString(text)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: center.x - width / 2, y: canvasHeight - center.y - (ascent - descent) / 2)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// `rect` (top-left origin) in a bottom-left canvas `canvasHeight` tall.
    static func flipped(_ rect: CGRect, canvasHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
