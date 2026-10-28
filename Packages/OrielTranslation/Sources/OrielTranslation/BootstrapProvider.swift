/// One entry of the `providers` array in `bootstrap.json` (PLAN §7.7.5, `docs/bootstrap.example.json`), decoded by
/// the app's bootstrap importer and handed to `TranslationCoordinator.applyBootstrap(_:defaultProvider:)`.
///
/// Only `id` and `kind` are required. The optional extras beyond the documented format let a shared config set the
/// same options as Settings.
public struct BootstrapProvider: Codable, Sendable, Equatable {
    /// The provider's id (`ollama`, `anthropic`), also its Keychain service suffix.
    public var id: String
    /// `openai-compatible`, `anthropic`, `google`, `deepl`, `apple` or `foundation-models`.
    public var kind: String
    public var baseURL: String?
    /// Model identifier; never defaulted in code.
    public var model: String?
    /// Stored in the Keychain, never in settings. An empty or missing key leaves the stored one alone.
    public var apiKey: String?
    public var displayName: String?
    public var temperature: Double?
    public var timeoutSeconds: Double?
    public var headers: [String: String]?
    /// DeepL: `default`, `prefer_more` or `prefer_less`.
    public var formality: String?
    /// Google: a Cloud Translation glossary, which switches the provider to v3 (needs `serviceAccountKey`).
    public var glossary: String?
    /// Google: the service account key for v3, stored in the Keychain.
    public var serviceAccountKey: BootstrapServiceAccountKey?

    public init(
        id: String,
        kind: String,
        baseURL: String? = nil,
        model: String? = nil,
        apiKey: String? = nil,
        displayName: String? = nil,
        temperature: Double? = nil,
        timeoutSeconds: Double? = nil,
        headers: [String: String]? = nil,
        formality: String? = nil,
        glossary: String? = nil,
        serviceAccountKey: BootstrapServiceAccountKey? = nil
    ) {
        self.id = id
        self.kind = kind
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.displayName = displayName
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.headers = headers
        self.formality = formality
        self.glossary = glossary
        self.serviceAccountKey = serviceAccountKey
    }
}
