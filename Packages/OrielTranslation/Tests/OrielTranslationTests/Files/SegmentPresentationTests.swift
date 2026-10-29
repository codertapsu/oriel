@testable import OrielTranslation
import Testing

/// How the file window shows segments: list markers, headings, quotes, code without fences, placeholders.
@MainActor
struct SegmentPresentationTests {
    @Test(arguments: [
        ("- ", "• "), ("* ", "• "), ("  + ", "  • "), ("12. ", "12. "), ("- [ ] ", "☐ "), ("- [x] ", "☑ "), ("> ", ""),
        ("> - ", "• "), ("## ", ""), ("", ""),
    ])
    func markers(_ prefix: String, _ shown: String) {
        #expect(SegmentPresentation.marker(for: prefix) == shown)
    }

    @Test func listItemsHeadingsAndQuotesKeepTheirLook() {
        let item = SegmentPresentation(DocumentSegment(id: 1, text: "Capture", prefix: "- "), translation: "キャプチャ", isFinished: true)
        #expect(item.original == "• Capture" && item.translation == "• キャプチャ" && item.kind == .text && !item.isPending)
        let heading = SegmentPresentation(DocumentSegment(id: 2, text: "Title", prefix: "## "), translation: nil, isFinished: false)
        #expect(heading.kind == .heading && heading.translation == "…" && heading.isPending)
        let quote = SegmentPresentation(DocumentSegment(id: 3, text: "Said", prefix: "> "), translation: nil, isFinished: true)
        #expect(quote.kind == .quote && quote.translation == "Not translated")
    }

    @Test func codeIsShownWithoutItsFencesOnBothSides() {
        let code = SegmentPresentation(
            DocumentSegment(id: 4, text: "", verbatim: "```swift\nlet x = 1\n```"),
            translation: nil,
            isFinished: false
        )
        #expect(code.kind == .code && code.original == "let x = 1" && code.translation == "let x = 1" && !code.isPending)
        #expect(SegmentPresentation.withoutFences("| a | b |\n| - | - |") == "| a | b |\n| - | - |")
    }
}
