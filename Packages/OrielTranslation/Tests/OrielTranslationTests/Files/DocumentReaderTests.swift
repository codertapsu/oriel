import AppKit
import OrielCore
@testable import OrielTranslation
import Testing

/// Reading real files, made in a temporary folder the test removes: text, Markdown, subtitles, RTF, Word, HTML,
/// images (with a fake OCR) and PDFs, a text page through PDFKit and a scanned page through OCR.
@MainActor
struct DocumentReaderTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "oriel-files-\(UUID().uuidString)")
    private let ocr = FakeTextRecognizer([
        OCRBlock(id: 1, text: "Scanned words", boundingBox: CGRect(x: 10, y: 10, width: 200, height: 30), confidence: 0.9),
    ])

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ text: String, to name: String, encoding: String.Encoding = .utf8) throws -> URL {
        let url = folder.appending(path: name)
        try #require(text.data(using: encoding)).write(to: url)
        return url
    }

    private func read(_ url: URL) async throws -> [DocumentPart] {
        let kind = try #require(DocumentKind.of(url))
        var parts: [DocumentPart] = []
        for try await part in DocumentReader.parts(of: url, kind: kind, recognizer: ocr, languages: []) {
            parts.append(part)
        }
        return parts
    }

    @Test func readsTextInWhateverEncodingItIs() async throws {
        defer { cleanUp() }
        let latin = try await read(write("Café crème.\n\nDeuxième paragraphe.", to: "menu.txt", encoding: .windowsCP1252))
        #expect(latin.first?.segments.map(\.text) == ["Café crème.", "Deuxième paragraphe."])
        let markdown = try await read(write("# Title\n\nBody.", to: "notes.md"))
        #expect(markdown.first?.segments.map(\.prefix) == ["# ", ""])
    }

    @Test func readsSubtitlesWithTheirCues() async throws {
        defer { cleanUp() }
        let parts = try await read(write("WEBVTT\n\n00:01.000 --> 00:02.000\nHello\n", to: "film.vtt"))
        let segment = try #require(parts.first?.segments.first)
        #expect(segment.text == "Hello" && segment.cue?.start == 1000 && parts.first?.subtitleHeader == "WEBVTT")
    }

    @Test func readsRichTextAndWordDocuments() async throws {
        defer { cleanUp() }
        let string = NSAttributedString(string: "First paragraph.\nSecond paragraph.\n", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let range = NSRange(location: 0, length: string.length)
        let rtf = folder.appending(path: "letter.rtf")
        try #require(string.rtf(from: range, documentAttributes: [:])).write(to: rtf)
        #expect(try await read(rtf).first?.segments.map(\.text) == ["First paragraph.", "Second paragraph."])
        let docx = folder.appending(path: "report.docx")
        try string.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]).write(to: docx)
        #expect(try await read(docx).first?.segments.map(\.text) == ["First paragraph.", "Second paragraph."])
    }

    @Test func readsImagesWithOCR() async throws {
        defer { cleanUp() }
        let url = folder.appending(path: "shot.png")
        try #require(ImageEncoder.data(TestSupport.image(width: 300, height: 120), type: .png)).write(to: url)
        let part = try #require(try await read(url).first)
        #expect(part.segments.map(\.text) == ["Scanned words"] && part.usedOCR && part.image?.width == 300 && part.blocks.count == 1)
    }

    @Test func readsPDFsPageByPageWithOCRForScannedPages() async throws {
        defer { cleanUp() }
        let url = folder.appending(path: "mixed.pdf")
        try PDFFixture.write(to: url)
        let parts = try await read(url)
        #expect(parts.map(\.page) == [1, 2] && parts.allSatisfy { $0.pageCount == 2 })
        #expect(parts[0].segments.map(\.text) == ["The first paragraph of the page.", "A second paragraph further down."])
        #expect(!parts[0].usedOCR && parts[1].usedOCR && parts[1].segments.map(\.text) == ["Scanned words"])
        #expect(parts.flatMap(\.segments).map(\.id) == [1, 2, 3] && parts[1].segments.first?.page == 2)
    }

    @Test func aLockedOrBrokenFileSaysSo() async throws {
        defer { cleanUp() }
        let url = try write("not a pdf", to: "broken.pdf")
        await #expect(throws: DocumentReader.ReadError.unreadable("broken.pdf")) {
            _ = try await read(url)
        }
    }
}
