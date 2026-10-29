import Foundation
@testable import OrielTranslation
import Testing

/// Chunking that respects each provider's limits and the document's paragraph boundaries.
struct DocumentChunkerTests {
    private func segments(_ texts: [String]) -> [DocumentSegment] {
        texts.enumerated().map { DocumentSegment(id: $0.offset + 1, text: $0.element) }
    }

    @Test func packsWholeSegmentsWithinTheCountAndCharacterLimits() {
        let limits = ChunkLimits(maxSegments: 3, maxCharacters: 25, maxSegmentCharacters: 100)
        let chunks = DocumentChunker.chunks(
            segments(["aaaaaaaaaa", "bbbbbbbbbb", "cc", "dd", String(repeating: "e", count: 23), "f"]),
            limits: limits
        )
        #expect(chunks.map { $0.pieces.map(\.segmentID) } == [[1, 2, 3], [4, 5], [6]])
        #expect(chunks.allSatisfy { $0.pieces.count <= 3 && $0.characterCount <= 25 })
        #expect(chunks.flatMap(\.pieces).map(\.requestID) == Array(1 ... 6))
    }

    @Test func leavesOutWhatIsNotTranslated() {
        var list = segments(["Text", "  ", "More"])
        list.append(DocumentSegment(id: 4, text: "", verbatim: "```\ncode\n```"))
        let chunks = DocumentChunker.chunks(list, limits: ChunkLimits(maxSegments: 10, maxCharacters: 100, maxSegmentCharacters: 100))
        #expect(chunks.flatMap(\.pieces).map(\.segmentID) == [1, 3])
    }

    @Test func splitsOnlyAnOverlongParagraphAtItsSentences() {
        let paragraph = "The first sentence is here. The second one follows it. A third ends the paragraph."
        let pieces = DocumentChunker.split(paragraph, maxCharacters: 60)
        #expect(pieces == ["The first sentence is here. The second one follows it.", "A third ends the paragraph."])
        #expect(DocumentChunker.split("Short.", maxCharacters: 60) == ["Short."])
        let limits = ChunkLimits(maxSegments: 10, maxCharacters: 1000, maxSegmentCharacters: 60)
        let chunk = DocumentChunker.chunks(segments(["Intro.", paragraph]), limits: limits, firstRequestID: 11)
        #expect(chunk.first?.pieces.map(\.part) == [0, 0, 1] && chunk.first?.pieces.map(\.segmentID) == [1, 2, 2])
        #expect(chunk.first?.pieces.map(\.requestID) == [11, 12, 13])
    }

    @Test func aSentenceTooLongForTheLimitIsSplitAtSpacesThenAnywhere() {
        let words = DocumentChunker.split("one two three four five six seven eight nine ten", maxCharacters: 15)
        #expect(words.allSatisfy { $0.count <= 15 } && words.joined(separator: " ") == "one two three four five six seven eight nine ten")
        let japanese = String(repeating: "あ", count: 25)
        #expect(DocumentChunker.split(japanese, maxCharacters: 10).map(\.count) == [10, 10, 5])
    }

    @Test func piecesJoinWithASpaceExceptForScriptsWithoutSpaces() {
        #expect(DocumentChunker.join(["Une phrase.", " Une autre."], target: Locale.Language(identifier: "fr")) == "Une phrase. Une autre.")
        #expect(DocumentChunker.join(["一つ目。", "二つ目。"], target: Locale.Language(identifier: "ja")) == "一つ目。二つ目。")
    }

    @Test func providerLimitsStayInsideWhatEachServiceTakes() {
        let deepl = ChunkLimits.limits(for: ProviderConfig(id: "deepl", kind: .deepl))
        #expect(deepl.maxSegments <= DeepLProvider.batchLimits.count && deepl.maxCharacters <= 128 * 1024)
        let small = ChunkLimits.limits(for: ProviderConfig(id: "a", kind: .anthropic, maxOutputTokens: 256))
        let large = ChunkLimits.limits(for: ProviderConfig(id: "b", kind: .anthropic, maxOutputTokens: 8192))
        #expect(small.maxCharacters == 1000 && large.maxCharacters == 16384)
        let local = ChunkLimits.limits(for: ProviderConfig(id: "ollama", kind: .openAICompatible))
        #expect(local.maxCharacters < ChunkLimits.limits(for: ProviderConfig(id: "apple", kind: .apple)).maxCharacters)
    }
}
