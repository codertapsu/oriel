/// How much of a document one request to a provider may carry (PLAN §17). The limits are kept well inside what each
/// service accepts, and small enough that progress moves, Stop is quick, and a failure loses little.
struct ChunkLimits: Equatable, Sendable {
    /// Segments per request.
    var maxSegments: Int
    /// Characters per request.
    var maxCharacters: Int
    /// A paragraph longer than this is split at sentences (then words) into pieces translated separately.
    var maxSegmentCharacters: Int

    static func limits(for config: ProviderConfig) -> ChunkLimits {
        switch config.kind {
        case .apple:
            // On-device; small chunks keep progress smooth.
            return ChunkLimits(maxSegments: 40, maxCharacters: 6000, maxSegmentCharacters: 3000)
        case .deepl:
            // DeepL takes 50 texts and 128 KiB per request.
            return ChunkLimits(maxSegments: 50, maxCharacters: 25000, maxSegmentCharacters: 5000)
        case .google:
            // Basic takes 128 texts; Google recommends at most 5,000 characters per text.
            return ChunkLimits(maxSegments: 100, maxCharacters: 20000, maxSegmentCharacters: 5000)
        case .openAICompatible:
            // Local models often have 4K–8K token contexts, and the answer repeats the input as JSON.
            return ChunkLimits(maxSegments: 30, maxCharacters: 3000, maxSegmentCharacters: 1500)
        case .anthropic:
            // The answer has to fit `max_tokens`: about two characters of input per output token is safe.
            let characters = min(24000, max(1000, config.maxOutputTokens * 2))
            return ChunkLimits(maxSegments: 60, maxCharacters: characters, maxSegmentCharacters: max(500, characters / 2))
        case .foundationModels:
            // A quarter of a 4,096-token context, with room for CJK text at one token per character.
            return ChunkLimits(maxSegments: 20, maxCharacters: 1500, maxSegmentCharacters: 700)
        }
    }
}
