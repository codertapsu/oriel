/// One provider's usage in one calendar month (`2026-10`), for the counter in Settings and the monthly cap.
struct ProviderUsage: Codable, Sendable, Equatable {
    var month: String
    var characters = 0
    var inputTokens = 0
    var outputTokens = 0
    var requests = 0

    var tokens: Int {
        inputTokens + outputTokens
    }

    /// The figure the cap applies to: tokens for LLM providers, characters for the others.
    func measure(countsTokens: Bool) -> Int {
        countsTokens ? tokens : characters
    }
}
