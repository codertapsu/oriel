import Foundation
@testable import OrielTranslation
import Testing

struct SegmentBatcherTests {
    private func segments(_ lengths: [Int]) -> [TranslationSegment] {
        lengths.enumerated().map { TranslationSegment(id: $0.offset + 1, text: String(repeating: "a", count: $0.element)) }
    }

    @Test func respectsCountAndCostLimitsAndKeepsOrder() {
        let input = segments([10, 10, 10, 30, 5, 5])
        let batches = SegmentBatcher.batches(input, maxCount: 2, maxCost: 25)
        #expect(batches.map { $0.map(\.id) } == [[1, 2], [3], [4], [5, 6]])
        #expect(batches.flatMap(\.self) == input)
        #expect(SegmentBatcher.batches([], maxCount: 5, maxCost: 5).isEmpty)
    }

    @Test func estimatesTokensGenerouslyForCJK() {
        let latin = SegmentBatcher.estimatedTokens(TranslationSegment(id: 1, text: String(repeating: "a", count: 70)))
        let japanese = SegmentBatcher.estimatedTokens(TranslationSegment(id: 1, text: String(repeating: "語", count: 70)))
        #expect(latin == 28 && japanese == 78)
    }
}
