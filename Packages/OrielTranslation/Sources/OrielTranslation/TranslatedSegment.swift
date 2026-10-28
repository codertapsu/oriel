/// A translation of one segment, as a provider streams it out. A provider may send the same id again with a better
/// text; the last one wins.
public struct TranslatedSegment: Sendable, Hashable {
    public let id: Int
    public let text: String
    /// The source text as the provider read it. Only AI Vision answers carry it, for text that OCR missed.
    public let source: String?

    public init(id: Int, text: String, source: String? = nil) {
        self.id = id
        self.text = text
        self.source = source
    }
}
