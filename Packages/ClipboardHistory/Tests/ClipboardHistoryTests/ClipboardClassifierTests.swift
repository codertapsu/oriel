@testable import ClipboardHistory
import Foundation
import SharedUI
import Testing

struct ClipboardClassifierTests {
    @Test func plainTextTakesItsFirstLineAsTheTitle() throws {
        let result = try #require(ClipboardClassifier.classify(Fixtures.text("\n\n   Hello    world  \nsecond line")))
        #expect(result.kind == .text)
        #expect(result.title == "Hello world")
        #expect(result.text == "\n\n   Hello    world  \nsecond line")
    }

    @Test func longTitlesAndTextsAreCut() throws {
        let long = String(repeating: "a", count: 20000)
        let result = try #require(ClipboardClassifier.classify(Fixtures.text(long)))
        #expect(result.title.count == ClipboardClassifier.titleLimit + 1)
        #expect(result.title.hasSuffix("…"))
        #expect(result.text?.count == ClipboardClassifier.textLimit)
    }

    @Test func formattedTextIsRichText() throws {
        let snapshot = Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("Bold move")),
            (ClipboardTypes.html, Fixtures.data("<b>Bold</b> move")),
        ])
        #expect(try #require(ClipboardClassifier.classify(snapshot)).kind == .richText)
    }

    @Test func rtfWithoutPlainTextStillGivesText() throws {
        let rtf = Fixtures.data("{\\rtf1\\ansi{\\fonttbl\\f0 Helvetica;}\\f0 Hello from RTF}")
        let result = try #require(ClipboardClassifier.classify(Fixtures.snapshot([(ClipboardTypes.rtf, rtf)])))
        #expect(result.kind == .richText)
        #expect(result.title == "Hello from RTF")
    }

    @Test(arguments: ["https://example.com/a?b=c", "mailto:me@example.com", "www.example.com", "vscode://file/a.swift"])
    func singleLinksAreLinks(_ text: String) throws {
        #expect(try #require(ClipboardClassifier.classify(Fixtures.text("  \(text)\n"))).kind == .link)
    }

    @Test(arguments: ["see https://example.com", "key:value", "10:30", "https://", "example.com/path with space"])
    func otherTextIsNotALink(_ text: String) {
        #expect(!ClipboardClassifier.isLink(text))
    }

    @Test func colorsAreRecognized() throws {
        let result = try #require(ClipboardClassifier.classify(Fixtures.text("#ff8800")))
        #expect(result.kind == .color)
        #expect(result.colorHex == "#FF8800")
    }

    @Test func imagesGetTheirSizeAndLabel() throws {
        let png = try Fixtures.png(width: 40, height: 30)
        let plain = try #require(ClipboardClassifier.classify(Fixtures.snapshot([(ClipboardTypes.png, png)])))
        #expect(plain.kind == .image)
        #expect(plain.title == "Image · 40 × 30")
        #expect(plain.pixelWidth == 40 && plain.pixelHeight == 30)
        let screenshot = try #require(ClipboardClassifier.classify(Fixtures.snapshot([(ClipboardTypes.png, png)]), label: "Screenshot"))
        #expect(screenshot.title == "Screenshot · 40 × 30")
        #expect(screenshot.contentHash == plain.contentHash)
    }

    /// A browser's Copy Image puts the image's address beside it as text.
    @Test func anImageBesideItsOwnAddressIsAnImage() throws {
        let png = try Fixtures.png()
        let snapshot = Fixtures.snapshot([
            (ClipboardTypes.png, png),
            (ClipboardTypes.plainText, Fixtures.data("https://example.com/a.png")),
        ])
        #expect(try #require(ClipboardClassifier.classify(snapshot)).kind == .image)
        let html = Fixtures.snapshot([(ClipboardTypes.html, Fixtures.data("<img src=\"a.png\">")), (ClipboardTypes.png, png)])
        #expect(try #require(ClipboardClassifier.classify(html)).kind == .image)
    }

    /// Word and Excel put a picture of the text beside the text.
    @Test func textWithAPictureOfItIsText() throws {
        let snapshot = try Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("Quarterly report")),
            (ClipboardTypes.rtf, Fixtures.data("{\\rtf1 Quarterly report}")),
            (ClipboardTypes.png, Fixtures.png()),
        ])
        #expect(try #require(ClipboardClassifier.classify(snapshot)).kind == .richText)
    }

    @Test func filesListTheirNamesAndResolvePaths() throws {
        let urls = [URL(filePath: "/tmp/report.pdf"), URL(filePath: "/tmp/photo.png"), URL(filePath: "/tmp/notes.txt")]
        let snapshot = PasteboardSnapshot(items: urls.map { [.init(type: ClipboardTypes.fileURL, data: Fixtures.data($0.absoluteString))] })
        let result = try #require(ClipboardClassifier.classify(snapshot))
        #expect(result.kind == .files)
        #expect(result.title == "report.pdf and 2 more")
        #expect(result.fileURLs?.map(\.path) == ["/tmp/report.pdf", "/tmp/photo.png", "/tmp/notes.txt"])
        #expect(result.text == "/tmp/report.pdf\n/tmp/photo.png\n/tmp/notes.txt")
    }

    @Test func otherDataIsDescribedByItsType() throws {
        let result = try #require(ClipboardClassifier.classify(Fixtures.snapshot([("com.example.private", Data([1, 2, 3]))]), label: nil))
        #expect(result.kind == .other)
        #expect(!result.title.isEmpty)
    }

    @Test func theSameTextFromAnotherAppHasTheSameHash() throws {
        let plain = try #require(ClipboardClassifier.classify(Fixtures.text("same words")))
        let formatted = try #require(ClipboardClassifier.classify(Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("same words")),
            (ClipboardTypes.html, Fixtures.data("<i>same words</i>")),
        ])))
        #expect(plain.contentHash == formatted.contentHash)
        #expect(try plain.contentHash != #require(ClipboardClassifier.classify(Fixtures.text("other words"))).contentHash)
    }

    @Test func emptyCopiesAreNotKept() {
        #expect(ClipboardClassifier.classify(PasteboardSnapshot(items: [])) == nil)
        #expect(ClipboardClassifier.classify(PasteboardSnapshot(items: [[]])) == nil)
    }

    @Test func htmlOnlyTextIsStrippedAndDecodedInOrder() throws {
        let snapshot = Fixtures.snapshot([(ClipboardTypes.html, Fixtures.data("<p>Fish &amp;lt;chips&amp;gt; &amp; peas</p>"))])
        #expect(try #require(ClipboardClassifier.classify(snapshot)).title == "Fish &lt;chips&gt; & peas")
    }
}
