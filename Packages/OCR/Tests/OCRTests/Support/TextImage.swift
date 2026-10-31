import CoreGraphics
import CoreText
import Testing

/// Images of text drawn in memory, for real Vision recognition.
enum TextImage {
    /// A line of text to draw: `top` is the distance from the image's top edge to the top of the line, in pixels.
    struct Line {
        let text: String
        let x: CGFloat
        let top: CGFloat
        let size: CGFloat

        init(_ text: String, x: CGFloat, top: CGFloat, size: CGFloat) {
            self.text = text
            self.x = x
            self.top = top
            self.size = size
        }
    }

    /// A white image with black Helvetica lines.
    static func render(_ lines: [Line], width: Int = 1200, height: Int = 600) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for line in lines {
            let font = CTFontCreateWithName("Helvetica" as CFString, line.size, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            ]
            let attributed = try #require(CFAttributedStringCreate(nil, line.text as CFString, attributes as CFDictionary))
            let ctLine = CTLineCreateWithAttributedString(attributed)
            // CoreGraphics puts y = 0 at the bottom; the baseline sits one ascent below the line's top.
            context.textPosition = CGPoint(x: line.x, y: CGFloat(height) - line.top - CTFontGetAscent(font))
            CTLineDraw(ctLine, context)
        }
        return try #require(context.makeImage())
    }

    /// A screenful of interface text, 1,000 × 600 px: a title and paragraphs at 13 pt on a Retina display (26 px),
    /// as a capture of a window would hold.
    static func screenful() throws -> CGImage {
        let sentences = [
            "Window Switcher shows every open window as a thumbnail, most recent first.",
            "Hold Option and press Tab to step through them; release to switch.",
            "Type while it is open to search titles and app names at once.",
            "Capture Area freezes the screen so menus and tooltips stay put.",
            "Translate Area reads the text in a region and shows it in place.",
            "Disk Space Analyzer lists the largest folders first and explains them.",
            "Clean Up checks a folder before anything is moved to the Trash.",
            "Clipboard History keeps text, images and files you copied today.",
            "Activity Monitor samples processes only while its window is open.",
            "Screen Ruler measures distances between edges on any display.",
            "Settings sync between Macs through a folder in iCloud Drive.",
            "Every command has a shortcut, a menu item and an oriel:// link.",
            "Press Escape at any time to close the panel without switching.",
        ]
        var lines = [Line("Oriel — what each tool does", x: 40, top: 24, size: 40)]
        lines += sentences.enumerated().map { index, text in Line(text, x: 40, top: 92 + CGFloat(index) * 38, size: 26) }
        return try render(lines, width: 1000, height: 600)
    }
}
