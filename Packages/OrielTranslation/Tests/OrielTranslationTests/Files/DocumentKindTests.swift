import Foundation
@testable import OrielTranslation
import Testing
import UniformTypeIdentifiers

/// File-type routing: by extension first, then by what the type conforms to.
struct DocumentKindTests {
    @Test(arguments: [
        ("photo.JPG", DocumentKind.image), ("scan.heic", .image), ("shot.png", .image), ("paper.pdf", .pdf),
        ("notes.txt", .plainText), ("README.md", .markdown), ("guide.markdown", .markdown), ("letter.rtf", .richText(.rtf)),
        ("bundle.rtfd", .richText(.rtfd)), ("report.docx", .richText(.docx)), ("old.doc", .richText(.doc)),
        ("draft.odt", .richText(.odt)), ("page.html", .html), ("page.htm", .html), ("film.srt", .subtitles(.srt)),
        ("film.vtt", .subtitles(.vtt)),
    ])
    func routesByExtension(_ name: String, _ expected: DocumentKind) {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        #expect(DocumentKind.of(fileExtension: url.pathExtension, type: nil) == expected)
    }

    @Test func fallsBackOnTheTypesConformance() {
        #expect(DocumentKind.of(fileExtension: "swift", type: .swiftSource) == .plainText)
        #expect(DocumentKind.of(fileExtension: "csv", type: .commaSeparatedText) == .plainText)
        #expect(DocumentKind.of(fileExtension: "gif2", type: .gif) == .image)
        #expect(DocumentKind.of(fileExtension: "zip", type: .zip) == nil)
        #expect(DocumentKind.of(fileExtension: "", type: nil) == nil)
    }

    @Test func eachKindOffersTheExportsThatFitIt() {
        #expect(DocumentKind.subtitles(.srt).exportFormats == [.srt, .vtt, .text])
        #expect(DocumentKind.image.exportFormats.first == .image)
        #expect(DocumentKind.markdown.exportFormats == [.text, .markdown, .bilingualMarkdown])
        #expect(DocumentKind.subtitles(.vtt).count(1) == "1 cue" && DocumentKind.pdf.count(12) == "12 paragraphs")
    }
}
