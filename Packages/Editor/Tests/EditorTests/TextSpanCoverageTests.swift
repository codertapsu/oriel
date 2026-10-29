import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// Smart Redact's boxes cover what they hide: text is drawn in several fonts, the line's tight ink box stands in for
/// OCR's line box, and every pixel of the matched part must fall inside the estimated box.
@MainActor
struct TextSpanCoverageTests {
    /// The ink's bounding box in a rendering of `text` at (10, 10) in `font`, with only `visible` (a UTF-16 range)
    /// drawn in black and the rest in white, in points at 1× on a white image.
    private func inkBox(of text: String, visible: NSRange?, font: NSFont) throws -> CGRect? {
        let width = 1400, height = 80
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let attributed = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        if let visible {
            attributed.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: (text as NSString).length))
            attributed.addAttribute(.foregroundColor, value: NSColor.black, range: visible)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        attributed.draw(at: CGPoint(x: 10, y: 10))
        NSGraphicsContext.restoreGraphicsState()
        let image = try #require(context.makeImage())
        let pixels = try PixelBuffer(image)
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width where pixels.pixel(x, y).red < 200 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    @Test(arguments: [
        ("Card on file: 4111 1111 1111 1111", "4111 1111 1111 1111"),
        ("Signed in as jane.doe@example.com", "jane.doe@example.com"),
        ("export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE # keep this private", "AKIAIOSFODNN7EXAMPLE"),
        ("Call me at +1 (415) 555-0132 tomorrow after the standup meeting", "+1 (415) 555-0132"),
        ("Wide WWWWW MMMMM then iiiii lllll and 203.0.113.42 at the end", "203.0.113.42"),
    ])
    func theEstimatedBoxCoversTheMatchInEveryFont(_ text: String, _ part: String) throws {
        let fonts = try [
            NSFont.systemFont(ofSize: 20),
            #require(NSFont(name: "Helvetica", size: 18)),
            #require(NSFont(name: "Menlo", size: 16)),
            NSFont.systemFont(ofSize: 13, weight: .semibold),
        ]
        let range = (text as NSString).range(of: part)
        for font in fonts {
            let line = try #require(try inkBox(of: text, visible: nil, font: font))
            let target = try #require(try inkBox(of: text, visible: range, font: font))
            let padding = max(RedactionPlanner.minimumPadding, line.height * RedactionPlanner.paddingFraction)
            let box = TextSpanEstimator.box(location: range.location, length: range.length, in: text, lineBox: line, padding: padding)
            #expect(box.contains(target), "\(font.fontName): \(target) not inside \(box)")
            // And it does not hide much more than the part: at most a few characters either side.
            #expect(box.width < target.width + line.width * 0.3, "\(font.fontName): \(box) is far wider than \(target)")
        }
    }
}
