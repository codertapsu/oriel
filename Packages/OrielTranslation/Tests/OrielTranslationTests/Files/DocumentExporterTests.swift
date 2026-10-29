import Foundation
@testable import OrielTranslation
import Testing

struct DocumentExporterTests {
    private let context = DocumentExporter.Context(title: "report.pdf", kind: .pdf, source: "en", target: "fr", provider: "DeepL")

    private var pages: [DocumentSegment] {
        [
            DocumentSegment(id: 1, text: "Page one text.", page: 1),
            DocumentSegment(id: 2, text: "More on page one.", page: 1),
            DocumentSegment(id: 3, text: "Page two text.", page: 2),
        ]
    }

    @Test func untranslatedSegmentsKeepTheirOriginal() {
        let text = DocumentExporter.plainText(pages, translations: [1: "Texte de la page un.", 3: "Texte de la page deux."])
        #expect(text == "Texte de la page un.\n\nMore on page one.\n\nTexte de la page deux.\n")
    }

    @Test func markdownOfAPDFHasAHeadingPerPage() {
        let markdown = DocumentExporter.markdown(pages, translations: [1: "Un.", 2: "Deux.", 3: "Trois."], context: context)
        #expect(markdown == "## Page 1\n\nUn.\n\nDeux.\n\n## Page 2\n\nTrois.\n")
    }

    @Test func bilingualMarkdownQuotesEachOriginal() {
        let markdown = DocumentExporter.bilingualMarkdown(pages, translations: [1: "Un."], context: context)
        #expect(markdown.contains("## Page 1\n\n> Page one text.") && markdown.contains("## Page 2\n\n> Page two text."))
        #expect(markdown.hasPrefix("# report.pdf\n\n*\(LanguageCatalog.name(of: "en")) → \(LanguageCatalog.name(of: "fr")) · DeepL*\n"))
        #expect(markdown.contains("> Page one text.\n\nUn.") && markdown.contains("> More on page one.\n\n*(not translated)*"))
    }

    @Test func subtitlesKeepTheirTimingAndTakeTheTranslation() throws {
        let parsed = SubtitleFile.parse("1\n00:00:01,000 --> 00:00:02,000\nHello\n\n2\n00:00:03,000 --> 00:00:04,500\nBye\n")
        let segments = parsed.cues.enumerated().map { DocumentSegment(id: $0.offset + 1, text: $0.element.plainText, cue: $0.element) }
        let srt = DocumentExporter.subtitles(segments, translations: [1: "Bonjour"], as: .srt, header: nil)
        #expect(srt == "1\n00:00:01,000 --> 00:00:02,000\nBonjour\n\n2\n00:00:03,000 --> 00:00:04,500\nBye\n\n")
        let data = try #require(DocumentExporter.data(
            .vtt, segments: segments, translations: [1: "Bonjour", 2: "Au revoir"],
            context: .init(title: "film.srt", kind: .subtitles(.srt), source: "en", target: "fr", provider: "Fake")
        ))
        #expect(String(bytes: data, encoding: .utf8)?.hasPrefix("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nBonjour\n\n") == true)
        #expect(DocumentExporter.data(.image, segments: segments, translations: [:], context: context) == nil)
    }

    @Test func suggestsTheFilesNameWithTheTargetLanguage() {
        let url = URL(fileURLWithPath: "/Users/me/Movies/film.en.srt")
        #expect(DocumentExporter.suggestedFileName(for: url, format: .srt, target: "ja") == "film.en.ja.srt")
        #expect(DocumentExporter.suggestedFileName(for: nil, format: .markdown, target: "fr") == "Translation.fr.md")
    }
}
