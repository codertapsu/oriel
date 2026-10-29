@testable import Capture
import Testing

/// What Capture Text's toast says it copied.
struct TextPreviewTests {
    @Test func oneShortLineIsShownWhole() {
        #expect(TextPreview.copiedMessage(for: "Total due: 1 280 €") == "Copied “Total due: 1 280 €”")
    }

    @Test func longTextIsCutAtAWordAndCountsItsLines() {
        let text = "Screenshots are the fastest way to share what you see.\nOriel keeps them.\n\nAll of them."
        #expect(TextPreview.copiedMessage(for: text) == "Copied “Screenshots are the fastest way to share…” · 3 lines")
        let midWord = "Screenshots are the fastest way to shareable things"
        #expect(TextPreview.excerpt(of: midWord) == "Screenshots are the fastest way to…")
    }

    @Test func whitespaceIsCollapsedAndBlankLinesSkipped() {
        #expect(TextPreview.excerpt(of: "\n\n  Name:\tJohn   Appleseed  \n") == "Name: John Appleseed")
        #expect(TextPreview.excerpt(of: "   ") == "")
    }

    @Test func aWordLongerThanTheLimitIsCutInside() {
        let word = String(repeating: "a", count: 60)
        #expect(TextPreview.excerpt(of: word) == String(repeating: "a", count: 40) + "…")
    }
}
