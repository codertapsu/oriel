/// One piece of text to translate, usually one OCR block. Ids are what the segment JSON contract echoes back
/// (`[{"id": 1, "text": "…"}]`, PLAN §7.7.4).
public struct TranslationSegment: Sendable, Codable, Hashable {
    public let id: Int
    public let text: String

    public init(id: Int, text: String) {
        self.id = id
        self.text = text
    }
}
