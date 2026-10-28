@testable import OrielTranslation
import Testing

struct SegmentParserTests {
    private let contract = #"[{"id":1,"translation":"Bonjour"},{"id":2,"translation":"Salut"}]"#

    private func parse(_ text: String, expected: [Int] = [1, 2]) -> [SegmentParser.Segment] {
        var parser = SegmentParser()
        return parser.feed(text) + parser.finish(expectedIDs: expected)
    }

    private func translations(_ segments: [SegmentParser.Segment]) -> [Int: String] {
        Dictionary(segments.map { ($0.id, $0.translation) }) { _, last in last }
    }

    @Test func readsTheContractsArray() {
        let segments = parse(contract)
        #expect(segments == [
            SegmentParser.Segment(id: 1, translation: "Bonjour", source: nil),
            SegmentParser.Segment(id: 2, translation: "Salut", source: nil),
        ])
    }

    @Test(arguments: [
        "Sure! Here is the translation:\n```json\n[{\"id\": 1, \"translation\": \"Bonjour\"},\n {\"id\": 2, \"translation\": \"Salut\"}]"
            + "\n```\nLet me know if you need anything else.",
        "The word \"hello\" becomes: [{\"id\":1,\"translation\":\"Bonjour\"},{\"id\":2,\"translation\":\"Salut\"}] I hope \"this\" helps",
        "Translations [as requested]: [{\"id\":1,\"translation\":\"Bonjour\"},{\"id\":2,\"translation\":\"Salut\"}]",
        "{\"translations\": [{\"id\": 1, \"translation\": \"Bonjour\"}, {\"id\": 2, \"translation\": \"Salut\"}]}",
    ])
    func toleratesProseCodeFencesAndAWrappingObject(_ answer: String) {
        #expect(translations(parse(answer)) == [1: "Bonjour", 2: "Salut"])
    }

    @Test func missingIDsAreLeftOut() {
        let segments = parse(#"[{"id":2,"translation":"Salut"}]"#, expected: [1, 2, 3])
        #expect(translations(segments) == [2: "Salut"])
    }

    @Test func unknownIDsArePassedOnForTheCallerToJudge() {
        #expect(translations(parse(#"[{"id":7,"translation":"Bonjour"}]"#)) == [7: "Bonjour"])
    }

    @Test func emitsEachSegmentAsSoonAsItsTranslationIsComplete() throws {
        var parser = SegmentParser()
        var emittedAt: [Int: Int] = [:]
        for (offset, character) in contract.enumerated() {
            for segment in parser.feed(String(character)) {
                emittedAt[segment.id] = offset
            }
        }
        let firstBrace = try #require(contract.firstIndex(of: "}"))
        let firstRecordEnd = contract.distance(from: contract.startIndex, to: firstBrace)
        // The first segment arrives with the brace after its closing quote, long before the second record ends.
        #expect(emittedAt[1] == firstRecordEnd)
        #expect(try #require(emittedAt[2]) > firstRecordEnd + 10)
        #expect(parser.finish(expectedIDs: [1, 2]).isEmpty)
    }

    @Test func givesTheSameResultWhereverTheStreamIsSplit() {
        let answer = #"Here: [{"id":1,"translation":"Café \"Ciel\"\nouvert"},{"translation":"Salut","id":"2"}]"#
        let expected = [1: "Café \"Ciel\"\nouvert", 2: "Salut"]
        for split in 0 ... answer.count {
            var parser = SegmentParser()
            let index = answer.index(answer.startIndex, offsetBy: split)
            let segments = parser.feed(String(answer[..<index])) + parser.feed(String(answer[index...])) + parser.finish(expectedIDs: [
                1,
                2,
            ])
            #expect(translations(segments) == expected, "split at \(split)")
        }
    }

    @Test func decodesEscapesAndSurrogatePairs() {
        let answer = #"[{"id":1,"translation":"Line one\nLine \"two\" \\ café 😀 \/ \t."}]"#
        #expect(translations(parse(answer, expected: [1])) == [1: "Line one\nLine \"two\" \\ café 😀 / \t."])
    }

    @Test func keepsUnescapedQuotesAndRawLineBreaksInsideStrings() {
        let answer = "[{\"id\":1,\"translation\":\"He said \"hi\" to me\"},{\"id\":2,\"translation\":\"Line one\nLine two\"}]"
        #expect(translations(parse(answer)) == [1: "He said \"hi\" to me", 2: "Line one\nLine two"])
    }

    @Test func acceptsStringIDsAnyKeyOrderAndNumberFormats() {
        let answer = #"[{"translation":"Bonjour","id":"1"},{"id":2.0,"translation":"Salut"},{"segment_id":3,"translated_text":"Coucou"}]"#
        #expect(translations(parse(answer, expected: [1, 2, 3])) == [1: "Bonjour", 2: "Salut", 3: "Coucou"])
    }

    @Test func readsMapsFromIDToTranslation() {
        #expect(translations(parse(#"{"1": "Bonjour", "2": "Salut"}"#)) == [1: "Bonjour", 2: "Salut"])
    }

    /// What qwen2.5:7b on Ollama actually sent for an unconstrained prompt: records in brackets instead of braces.
    @Test func readsRecordsWrittenWithBrackets() {
        let answer = #"["id":1,"translation":"Bonjour le monde"],["id":2,"translation":"Bon matin"]"#
        #expect(translations(parse(answer)) == [1: "Bonjour le monde", 2: "Bon matin"])
    }

    @Test func takesAnEchoedTextKeyAsTheTranslation() {
        #expect(translations(parse(#"[{"id":1,"text":"Bonjour"},{"id":2,"text":"Salut"}]"#)) == [1: "Bonjour", 2: "Salut"])
    }

    @Test func reportsARepeatedIDAgainWithItsNewText() {
        let segments = parse(#"[{"id":1,"translation":"Bonjour"},{"id":1,"translation":"Salut"}]"#)
        #expect(segments.map(\.translation) == ["Bonjour", "Salut"])
    }

    @Test func fallsBackToPositionsWhenTheAnswerHasNoIDs() {
        #expect(translations(parse(#"["Bonjour", "Salut"]"#)) == [1: "Bonjour", 2: "Salut"])
        #expect(translations(parse(#"[{"translation":"Bonjour"},{"translation":"Salut"}]"#, expected: [4, 9])) == [
            4: "Bonjour",
            9: "Salut",
        ])
        #expect(translations(parse("Bonjour le monde", expected: [7])) == [7: "Bonjour le monde"])
        #expect(translations(parse("```\nBonjour\nSalut\n```", expected: [1, 2])) == [1: "Bonjour", 2: "Salut"])
        #expect(parse("I can't help with that.", expected: [1, 2]).isEmpty)
    }

    @Test func keepsWhatWasCompleteWhenTheStreamIsCutOff() {
        let segments = parse(#"[{"id":1,"translation":"Bonjour"},{"id":2,"translation":"Sal"#)
        #expect(translations(segments) == [1: "Bonjour"])
    }

    @Test func readsCumulativeSnapshots() {
        var parser = SegmentParser()
        #expect(parser.feed(cumulative: #"[{"id":1,"transl"#).isEmpty)
        #expect(parser.feed(cumulative: #"[{"id":1,"translation":"Bonjour"}"#).map(\.id) == [1])
        #expect(parser.feed(cumulative: contract).map(\.id) == [2])
        #expect(parser.finish(expectedIDs: [1, 2]).isEmpty)
    }

    @Test func carriesTheSourceTextOfAIVisionAnswers() {
        let segments = parse(#"[{"id":1001,"translation":"Vertical writing","source":"縦書き"}]"#, expected: [])
        #expect(segments.last == SegmentParser.Segment(id: 1001, translation: "Vertical writing", source: "縦書き"))
    }
}
