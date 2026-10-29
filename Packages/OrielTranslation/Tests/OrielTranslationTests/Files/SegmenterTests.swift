import Foundation
@testable import OrielTranslation
import Testing

/// How text, Markdown, HTML and rich text files are split into the segments that are translated and exported.
struct SegmenterTests {
    // MARK: - Plain text

    @Test func plainTextParagraphsAreSeparatedByBlankLines() {
        let text = "\u{FEFF}First paragraph.\r\n\r\n\r\nSecond, with\na short line.\n  \nThird."
        #expect(PlainTextSegmenter.paragraphs(text) == ["First paragraph.", "Second, with\na short line.", "Third."])
    }

    @Test func hardWrappedProseIsJoinedButListsAreNot() {
        let wrapped = """
        This paragraph was wrapped at seventy-two columns by an editor, so every
        line but the last is long, and the words belong together as sentences that
        a translator should see whole.
        """
        #expect(PlainTextSegmenter.paragraphs(wrapped) == [
            "This paragraph was wrapped at seventy-two columns by an editor, so every line but the last is long, and the words "
                + "belong together as sentences that a translator should see whole.",
        ])
        let list = "- first item that is quite long, long enough to look wrapped at first\n- second item"
        #expect(PlainTextSegmenter.paragraphs(list) == [list])
    }

    // MARK: - Markdown

    @Test func markdownKeepsMarkersAsideAndCodeAsItIs() {
        let markdown = """
        ---
        title: Guide
        ---

        # Getting *started*

        Oriel lives in
        the menu bar.

        - Capture the screen
        - [ ] Translate it
          with a wrapped item
        1. First

        > A quote
        > on two lines

        ```swift
        let x = 1 // not translated
        ```

        | Key | Action |
        | --- | ------ |
        | ⌘C  | Copy   |

        Setext heading
        ==============

        ***
        """
        let segments = MarkdownSegmenter.segments(markdown)
        #expect(segments.map(\.prefix) == ["", "# ", "", "- ", "- [ ] ", "1. ", "> ", "", "", "# ", ""])
        #expect(segments.map(\.text) == [
            "", "Getting *started*", "Oriel lives in the menu bar.", "Capture the screen", "Translate it with a wrapped item",
            "First", "A quote on two lines", "", "", "Setext heading", "",
        ])
        #expect(segments[0].verbatim == "---\ntitle: Guide\n---")
        #expect(segments[7].verbatim == "```swift\nlet x = 1 // not translated\n```")
        #expect(segments[8].verbatim?.hasPrefix("| Key | Action |") == true)
        #expect(segments[10].verbatim == "***")
        #expect(segments.map(\.endsBlock) == [true, true, true, false, false, true, true, true, true, true, true])
        #expect(segments.map(\.id) == Array(1 ... 11))
    }

    @Test func indentedCodeIsKeptUnlessItContinuesAListItem() {
        let markdown = "Text:\n\n    code line\n    more code\n\n- item\n\n    continued paragraph"
        let segments = MarkdownSegmenter.segments(markdown)
        #expect(segments.map(\.verbatim) == [nil, "    code line\n    more code", nil, nil])
        #expect(segments.last?.prefix == "    " && segments.last?.text == "continued paragraph")
    }

    @Test func markdownExportRebuildsTheStructure() {
        let markdown = "# Title\n\nSome text.\n\n- One\n- Two\n\n```\ncode\n```\n"
        let segments = MarkdownSegmenter.segments(markdown)
        let translations = Dictionary(uniqueKeysWithValues: segments.filter(\.isTranslatable).map { ($0.id, "T(\($0.text))") })
        let context = DocumentExporter.Context(title: "notes.md", kind: .markdown, source: "en", target: "fr", provider: "Fake")
        #expect(DocumentExporter.markdown(segments, translations: translations, context: context)
            == "# T(Title)\n\nT(Some text.)\n\n- T(One)\n- T(Two)\n\n```\ncode\n```\n")
    }

    // MARK: - HTML

    @Test func htmlBecomesBlocksWithoutScriptsStylesOrTheHead() {
        let html = """
        <!DOCTYPE html><html><head><title>Ignored</title><style>p { color: red }</style></head>
        <body><h1>Caf&eacute; &amp; more</h1>
        <p>First   paragraph<br>with a break, <a href="x">a link</a>.</p>
        <script>document.write("<p>no</p>")</script>
        <ul><li>One</li><li>Two <b>bold</b></li></ul>
        <ol><li>First</li><li>Second</li></ol>
        <blockquote><p>Quoted</p></blockquote>
        <pre>  let x = 1
          let y = 2</pre>
        <!-- a comment <p>hidden</p> -->
        <table><tr><td>Cell A</td><td>Cell &#x42;</td></tr></table>
        </body></html>
        """
        let segments = HTMLTextExtractor.segments(html)
        #expect(segments.map(\.text) == [
            "Café & more", "First paragraph\nwith a break, a link.", "One", "Two bold", "First", "Second", "Quoted", "",
            "Cell A", "Cell B",
        ])
        #expect(segments.map(\.prefix) == ["# ", "", "- ", "- ", "1. ", "2. ", "> ", "", "", ""])
        #expect(segments[7].verbatim == "```\n  let x = 1\n  let y = 2\n```")
        #expect(segments.map(\.endsBlock) == [true, true, false, true, false, true, true, true, true, true])
    }

    @Test func entitiesDecode() {
        #expect(HTMLEntities
            .decode("&lt;b&gt; &quot;x&quot; &#233;&#xE9; &nbsp;&unknown; & alone") == "<b> \"x\" éé \u{00A0}&unknown; & alone")
    }

    // MARK: - Rich text

    @Test func richTextParagraphsTurnListMarkersIntoMarkdown() {
        let text = "Title\n\u{2029}•\tFirst item\n•\tSecond item\n2.\tNumbered\nPlain \u{FFFC}paragraph\u{2028}with a line break\n\n"
        let segments = DocumentReader.richTextSegments(text)
        #expect(segments.map(\.text) == ["Title", "First item", "Second item", "Numbered", "Plain paragraph\nwith a line break"])
        #expect(segments.map(\.prefix) == ["", "- ", "- ", "2. ", ""])
        #expect(segments.map(\.endsBlock) == [true, false, false, true, true])
    }
}
