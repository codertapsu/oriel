@testable import Capture
import CoreGraphics
import OrielCore
import Testing

/// Capture Text's reading order and joining (PLAN §17): line breaks kept, blank lines between paragraphs and columns,
/// tabs between table cells, and words a line-end hyphen split joined again.
struct TextLayoutTests {
    /// A recognized line in image pixels, top-left origin; 24 px tall like 13 pt text on a 2× display.
    private func line(_ text: String, x: CGFloat = 40, y: CGFloat, width: CGFloat? = nil, height: CGFloat = 24) -> OCRBlock {
        OCRBlock(
            id: 0,
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width ?? CGFloat(text.count) * 12, height: height),
            confidence: 1
        )
    }

    /// Lines 38 px apart (14 px between them), from `top`.
    private func column(_ texts: [String], x: CGFloat = 40, top: CGFloat, width: CGFloat? = nil) -> [OCRBlock] {
        texts.enumerated().map { index, text in line(text, x: x, y: top + CGFloat(index) * 38, width: width) }
    }

    private func text(_ blocks: [OCRBlock], words: Set<String> = []) -> String {
        TextLayout(blocks: blocks).text(dictionaryWords: words)
    }

    @Test func lineBreaksAreKept() {
        let blocks = column(["Screenshots are the fastest way", "to share what you see.", "Oriel keeps them all."], top: 10)
        #expect(text(blocks) == "Screenshots are the fastest way\nto share what you see.\nOriel keeps them all.")
    }

    @Test func aWideGapStartsAParagraph() {
        let first = column(["The first paragraph has", "two lines."], top: 10)
        let second = column(["The second one", "has two as well."], top: 140)
        #expect(text(first + second) == "The first paragraph has\ntwo lines.\n\nThe second one\nhas two as well.")
    }

    @Test func evenlySpacedRowsGetNoBlankLines() {
        // A list in a window: generous, even spacing is not a paragraph break.
        let rows = ["Desktop", "Documents", "Downloads", "Pictures", "Music"].enumerated().map { index, name in
            line(name, y: 10 + CGFloat(index) * 52)
        }
        #expect(text(rows) == "Desktop\nDocuments\nDownloads\nPictures\nMusic")
    }

    @Test func columnsOfProseAreReadOneAfterTheOther() {
        let left = column(["The left column starts", "here and continues on", "several lines of text", "until it ends here."], top: 120)
        let right = column(
            ["The right column is read", "after the left one, from", "the top to the bottom,", "like a newspaper page."],
            x: 480,
            top: 120,
            width: 260
        )
        let title = line("Two Column Title", x: 40, y: 20, width: 300, height: 36)
        let expected = """
        Two Column Title

        The left column starts
        here and continues on
        several lines of text
        until it ends here.

        The right column is read
        after the left one, from
        the top to the bottom,
        like a newspaper page.
        """
        #expect(text([title] + left + right) == expected)
        // A centred title over both columns changes nothing.
        let centred = line("Two Column Title", x: 260, y: 20, width: 320, height: 36)
        #expect(text([centred] + left + right) == expected)
    }

    @Test func formsAndTablesReadRowByRowWithTabs() {
        let labels = column(["Name:", "Email:", "Plan:"], x: 40, top: 60)
        let values = column(["John Appleseed", "john@example.com", "Team, 5 seats"], x: 260, top: 60)
        #expect(text(labels + values) == "Name:\tJohn Appleseed\nEmail:\tjohn@example.com\nPlan:\tTeam, 5 seats")
    }

    @Test func nearbyPiecesOfOneLineAreJoinedWithASpace() {
        let blocks = [line("Hello", x: 0, y: 10, width: 60), line("world", x: 70, y: 11, width: 60)]
        #expect(text(blocks) == "Hello world")
    }

    @Test func theOrderOfVisionsResultsDoesNotMatter() {
        let labels = column(["Name:", "Email:"], x: 40, top: 60)
        let values = column(["John Appleseed", "john@example.com"], x: 260, top: 60)
        let blocks = labels + values
        #expect(text(blocks.reversed()) == text(blocks))
        #expect(text([blocks[3], blocks[0], blocks[2], blocks[1]]) == text(blocks))
    }

    @Test func rightToLeftRowsReadFromTheRight() {
        let blocks = [line("عالم", x: 0, y: 10, width: 60), line("مرحبا", x: 200, y: 10, width: 80)]
        #expect(text(blocks) == "مرحبا\tعالم")
    }

    @Test func emptyLinesAreDropped() {
        #expect(text([]) == "")
        #expect(text([line("  ", y: 10), line("Only this", y: 50)]) == "Only this")
        #expect(TextLayout(blocks: [line("\n", y: 0)]).rows.isEmpty)
    }

    @Test func aDictionaryWordSplitByAHyphenIsJoined() {
        let blocks = column(["Oriel keeps a search-", "able history of captures."], top: 10)
        let layout = TextLayout(blocks: blocks)
        #expect(layout.hyphenatedWords == ["searchable"])
        #expect(layout.text(dictionaryWords: ["searchable"]) == "Oriel keeps a searchable history of captures.")
    }

    @Test func aCompoundWordKeepsItsHyphen() {
        let blocks = column(["A well-", "known trick, from pages 10-", "20 of the manual, by Jean-", "Paul."], top: 10)
        #expect(text(blocks, words: ["searchable"]) == "A well-known trick, from pages 10-20 of the manual, by Jean-Paul.")
    }

    @Test func dashesAndParagraphsKeepTheirLineBreaks() {
        let dash = column(["Wait -", "what happened?"], top: 10)
        #expect(text(dash, words: ["waitwhat"]) == "Wait -\nwhat happened?")
        let enDash = column(["Pages 10–", "20 are missing."], top: 10)
        #expect(text(enDash) == "Pages 10–\n20 are missing.")
        let paragraphs = column(["The end of a para-"], top: 10) + column(["graph is not joined."], top: 200)
        #expect(text(paragraphs, words: ["paragraph"]) == "The end of a para-\n\ngraph is not joined.")
    }

    @Test func aSoftHyphenIsAlwaysJoined() {
        let blocks = column(["Unter\u{00AD}", "nehmen"], top: 10)
        #expect(text(blocks) == "Unternehmen")
    }
}
