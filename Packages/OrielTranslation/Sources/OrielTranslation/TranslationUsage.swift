/// What one translation request used: characters sent (what machine-translation services bill) and, for LLMs, the
/// tokens the server reported (zero when it reported none).
public struct TranslationUsage: Sendable, Equatable, Codable {
    public var characters: Int
    public var inputTokens: Int
    public var outputTokens: Int

    public init(characters: Int, inputTokens: Int = 0, outputTokens: Int = 0) {
        self.characters = characters
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}
