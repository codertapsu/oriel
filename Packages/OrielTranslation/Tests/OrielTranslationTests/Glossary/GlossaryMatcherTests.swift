import Foundation
@testable import OrielTranslation
import Testing

struct GlossaryMatcherTests {
    private func found(_ terms: [GlossaryTerm], in text: String) -> [String] {
        GlossaryMatcher.matches(terms, in: text).map { String(text[$0.range]) }
    }

    @Test func findsWholeWordsOnlyInSpacedScripts() {
        let cat = GlossaryTerm(source: "cat", target: "chat")
        #expect(found([cat], in: "A cat, a category and a bobcat. Cat!") == ["cat", "Cat"])
        #expect(found([GlossaryTerm(source: "C++", target: "C++")], in: "I write C++ daily") == ["C++"])
    }

    @Test func findsTermsInsideUnspacedText() {
        let tokyo = GlossaryTerm(source: "東京", target: "Tokyo")
        #expect(found([tokyo], in: "東京都に住んでいます。東京は大きい。") == ["東京", "東京"])
        let capture = GlossaryTerm(source: "capture", target: "キャプチャ")
        #expect(found([capture], in: "画面をcaptureする") == ["capture"])
    }

    @Test func respectsCaseSensitivity() {
        let company = GlossaryTerm(source: "Apple", target: "Apple", isCaseSensitive: true)
        let fruit = GlossaryTerm(source: "apple", target: "pomme", isCaseSensitive: true)
        let matches = GlossaryMatcher.matches([company, fruit], in: "Apple sells apple pie, not APPLE juice.")
        #expect(matches.map(\.term.target) == ["Apple", "pomme"])
        let anyCase = GlossaryTerm(source: "apple", target: "pomme")
        #expect(found([anyCase], in: "Apple apple APPLE") == ["Apple", "apple", "APPLE"])
    }

    @Test func prefersTheLongestOverlappingTerm() {
        let york = GlossaryTerm(source: "York", target: "York")
        let newYork = GlossaryTerm(source: "New York", target: "ニューヨーク")
        let matches = GlossaryMatcher.matches([york, newYork], in: "From New York to York.")
        #expect(matches.map(\.term.target) == ["ニューヨーク", "York"])
    }

    @Test func occurringTermsLeaveOutTermsOnlyInsideLongerOnes() {
        let york = GlossaryTerm(source: "York", target: "York")
        let newYork = GlossaryTerm(source: "New York", target: "ニューヨーク")
        let unused = GlossaryTerm(source: "Paris", target: "パリ")
        let blank = GlossaryTerm(source: "  ", target: "x")
        let occurring = GlossaryMatcher.occurring([york, newYork, unused, blank], in: ["I love New York.", "Nothing here"])
        #expect(occurring.map(\.source) == ["New York"])
    }
}
