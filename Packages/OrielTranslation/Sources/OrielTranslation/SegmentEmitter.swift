/// Feeds an LLM's streamed answer through a `SegmentParser` and yields each segment as soon as it is complete.
struct SegmentEmitter {
    typealias Continuation = AsyncThrowingStream<TranslationEvent, any Error>.Continuation

    private var parser = SegmentParser()
    private let continuation: Continuation
    private let expectedIDs: [Int]
    /// Ids that received a translation, for providers that retry what a model left out.
    private(set) var translatedIDs: Set<Int> = []

    init(continuation: Continuation, expectedIDs: [Int]) {
        self.continuation = continuation
        self.expectedIDs = expectedIDs
    }

    mutating func feed(_ delta: String) {
        emit(parser.feed(delta))
    }

    mutating func feed(cumulative text: String) {
        emit(parser.feed(cumulative: text))
    }

    mutating func finish() {
        emit(parser.finish(expectedIDs: expectedIDs))
    }

    private mutating func emit(_ segments: [SegmentParser.Segment]) {
        for segment in segments {
            translatedIDs.insert(segment.id)
            continuation.yield(.segment(TranslatedSegment(id: segment.id, text: segment.translation, source: segment.source)))
        }
    }
}
