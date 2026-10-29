import AppKit
import Testing

/// A two-page PDF made during the test: page 1 has two paragraphs of real text, page 2 is only a picture, like a scan.
@MainActor
enum PDFFixture {
    static func write(to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        NSAttributedString(string: "The first paragraph of the page.", attributes: attributes).draw(at: CGPoint(x: 72, y: 700))
        NSAttributedString(string: "A second paragraph further down.", attributes: attributes).draw(at: CGPoint(x: 72, y: 620))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.beginPDFPage(nil)
        try context.draw(
            TestSupport.image(width: 400, height: 300, red: 0.9, green: 0.9, blue: 0.8),
            in: CGRect(x: 100, y: 300, width: 400, height: 300)
        )
        context.endPDFPage()
        context.closePDF()
    }
}
