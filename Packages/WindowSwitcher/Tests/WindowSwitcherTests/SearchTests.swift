import AppKit
import Testing
@testable import WindowSwitcher

/// Subsequence fuzzy search over "title app" with highlights (PLAN §7.1.10).
struct SearchTests {
    @Test(arguments: [
        ("saf", "Safari", [0, 1, 2]),
        ("gh", "GitHub", [0, 3]),
        ("ntpd", "Notepad", [0, 2, 4, 6]),
        ("cafe", "Café Menu", [0, 1, 2, 3]),
        ("TERM", "terminal", [0, 1, 2, 3]),
    ])
    func subsequencesMatchAndReportTheirCharacters(_ query: String, _ text: String, _ indices: [Int]) {
        #expect(FuzzyMatcher.match(query, in: text)?.indices == indices)
    }

    @Test(arguments: [("xyz", "Safari"), ("safarix", "Safari"), ("ba", "ab")])
    func missingCharactersDoNotMatch(_ query: String, _ text: String) {
        #expect(FuzzyMatcher.match(query, in: text) == nil)
    }

    @Test func emptyQueriesMatchEverything() {
        #expect(FuzzyMatcher.match("", in: "Anything") == FuzzyMatch(score: 0, indices: []))
        #expect(FuzzyMatcher.match("   ", in: "Anything") == FuzzyMatch(score: 0, indices: []))
    }

    @Test func wordsMatchInAnyOrder() {
        let match = FuzzyMatcher.match("safari git", in: "GitHub — Safari")
        #expect(match?.indices == [0, 1, 2, 9, 10, 11, 12, 13, 14])
    }

    @Test func wordStartsAndRunsBeatScatteredLetters() throws {
        let start = try #require(FuzzyMatcher.match("term", in: "Terminal"))
        let middle = try #require(FuzzyMatcher.match("term", in: "Determine"))
        #expect(start.score > middle.score)
        let run = try #require(FuzzyMatcher.match("note", in: "Notes"))
        let scattered = try #require(FuzzyMatcher.match("note", in: "No time"))
        #expect(run.score > scattered.score)
    }

    @Test func theBestAlignmentWins() {
        // The first "s" is in "Files"; "safari" matches better at the start of "Safari".
        #expect(FuzzyMatcher.match("saf", in: "Files Safari")?.indices == [6, 7, 8])
    }

    @Test func rankingOrdersByScoreAndKeepsMRUOrderForTies() {
        let entries = [
            Fixture.entry(1, app: "Finder", title: "Determine"),
            Fixture.entry(2, app: "Terminal", title: "zsh"),
            Fixture.entry(3, app: "Mail", title: "Inbox"),
            Fixture.entry(4, app: "Terminal", title: "ssh"),
        ]
        #expect(SearchRanker.rank(entries, query: "term").map(\.entry.id) == [2, 4, 1])
        #expect(SearchRanker.rank(entries, query: "").map(\.entry.id) == [1, 2, 3, 4])
        #expect(SearchRanker.rank(entries, query: "qq").isEmpty)
    }

    @Test func highlightsAreSplitBetweenTitleAndAppName() throws {
        let entries = [Fixture.entry(1, app: "Safari", title: "GitHub")]
        let ranked = try #require(SearchRanker.rank(entries, query: "git saf").first)
        #expect(ranked.titleMatches == [0, 1, 2])
        #expect(ranked.appMatches == [0, 1, 2])
    }

    @Test @MainActor func highlightedTextMarksTheMatchedCharacters() {
        let text = HighlightedText.make("Café Menu", matches: [0, 3], font: .systemFont(ofSize: 12), color: .labelColor)
        #expect(text.string == "Café Menu")
        let highlighted = (0 ..< text.length).filter { index in
            (text.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor) == .controlAccentColor
        }
        #expect(highlighted == [0, 3])
    }
}
