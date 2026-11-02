/// The implementation behind a provider (PLAN §7.7.2). The raw values are the `kind` strings of the bootstrap file.
public enum ProviderKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case apple
    /// Any `/v1/chat/completions` server: OpenAI, Ollama, LM Studio, llama.cpp.
    case openAICompatible = "openai-compatible"
    case foundationModels = "foundation-models"
    case anthropic
    case google
    case deepl

    public var id: String {
        rawValue
    }

    /// Whether translating with it needs Oriel Pro: everything but Apple Translation and Apple Intelligence on this Mac.
    public var needsPro: Bool {
        self != .apple && self != .foundationModels
    }

    public var displayName: String {
        switch self {
        case .apple: "Apple Translation"
        case .openAICompatible: "OpenAI-compatible"
        case .foundationModels: "Apple Intelligence"
        case .anthropic: "Anthropic"
        case .google: "Google Translate"
        case .deepl: "DeepL"
        }
    }

    /// The endpoint used when the configuration leaves it empty. Endpoints are not model identifiers, so they may
    /// have defaults; models never do (PLAN §7.7.2). OpenAI-compatible servers have no single default.
    var defaultBaseURL: String? {
        switch self {
        case .anthropic: "https://api.anthropic.com"
        case .google: "https://translation.googleapis.com/language/translate/v2"
        case .deepl: "https://api.deepl.com"
        case .apple, .openAICompatible, .foundationModels: nil
        }
    }

    var capabilities: ProviderCapabilities {
        switch self {
        case .apple: [.streaming, .offline, .autoDetect, .batch] // detects the source with NaturalLanguage
        case .openAICompatible: [.streaming, .imageInput, .autoDetect, .batch]
        case .foundationModels: [.streaming, .offline, .autoDetect, .batch]
        case .anthropic: [.streaming, .imageInput, .autoDetect, .batch]
        case .google, .deepl: [.autoDetect, .batch]
        }
    }

    /// Whether a request cannot work without an API key. Local OpenAI-compatible servers usually need none.
    var requiresAPIKey: Bool {
        switch self {
        case .anthropic, .google, .deepl: true
        case .apple, .openAICompatible, .foundationModels: false
        }
    }

    /// Whether the provider talks to a server, and therefore needs an endpoint and the network.
    var usesNetwork: Bool {
        switch self {
        case .apple, .foundationModels: false
        case .openAICompatible, .anthropic, .google, .deepl: true
        }
    }

    /// Whether a model has to be chosen before the provider can translate.
    var requiresModel: Bool {
        switch self {
        case .openAICompatible, .anthropic: true
        case .apple, .foundationModels, .google, .deepl: false
        }
    }

    /// LLM providers bill tokens, machine-translation services bill characters.
    var countsTokens: Bool {
        switch self {
        case .openAICompatible, .anthropic, .foundationModels: true
        case .apple, .google, .deepl: false
        }
    }
}
