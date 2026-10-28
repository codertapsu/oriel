/// The choices of Settings → Translation → "Add Provider". Presets fill in an endpoint where a product has a well-known
/// one; models are always left to the user, a bootstrap file or "Fetch models".
enum ProviderPreset: String, CaseIterable, Identifiable {
    case openAI
    case ollama
    case lmStudio
    case llamaCpp
    case otherOpenAICompatible
    case anthropic
    case google
    case deepl

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .ollama: "Ollama"
        case .lmStudio: "LM Studio"
        case .llamaCpp: "llama.cpp"
        case .otherOpenAICompatible: "Other OpenAI-compatible Server"
        case .anthropic: "Anthropic"
        case .google: "Google Translate"
        case .deepl: "DeepL"
        }
    }

    var kind: ProviderKind {
        switch self {
        case .openAI, .ollama, .lmStudio, .llamaCpp, .otherOpenAICompatible: .openAICompatible
        case .anthropic: .anthropic
        case .google: .google
        case .deepl: .deepl
        }
    }

    var suggestedID: String {
        switch self {
        case .openAI: "openai"
        case .ollama: "ollama"
        case .lmStudio: "lmstudio"
        case .llamaCpp: "llamacpp"
        case .otherOpenAICompatible: "server"
        case .anthropic: "anthropic"
        case .google: "google"
        case .deepl: "deepl"
        }
    }

    var baseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .ollama: "http://localhost:11434/v1"
        case .lmStudio: "http://localhost:1234/v1"
        case .llamaCpp: "http://localhost:8080/v1"
        case .otherOpenAICompatible, .anthropic, .google, .deepl: ""
        }
    }

    /// A readable name for a provider that arrives without one (bootstrap files usually give only an id).
    static func displayName(forID id: String, kind: ProviderKind) -> String {
        let normalized = id.lowercased().filter { $0.isLetter || $0.isNumber }
        if let preset = allCases.first(where: { $0 != .otherOpenAICompatible && $0.suggestedID == normalized && $0.kind == kind }) {
            return preset.title
        }
        guard kind == .openAICompatible else { return kind.displayName }
        return id.prefix(1).uppercased() + id.dropFirst()
    }
}
