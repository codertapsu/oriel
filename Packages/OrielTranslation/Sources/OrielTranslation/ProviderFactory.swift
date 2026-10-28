/// Builds a provider from its configuration and key. Providers are cheap values, built for each translation, so a
/// changed setting or key takes effect at once.
struct ProviderFactory: Sendable {
    let http: HTTPClient

    /// `serviceAccount` is the Google key file for glossaries (Cloud Translation v3); other kinds ignore it.
    func make(
        _ config: ProviderConfig,
        apiKey: APIKey?,
        serviceAccount: GoogleServiceAccount? = nil,
        appleHighFidelity: Bool
    ) -> any TranslationProvider {
        switch config.kind {
        case .apple:
            AppleTranslationProvider(
                id: config.id, displayName: config.displayName, backend: SystemTranslationBackend(prefersHighFidelity: appleHighFidelity)
            )
        case .openAICompatible:
            OpenAICompatibleProvider(config: config, apiKey: apiKey, http: http)
        case .foundationModels:
            FoundationModelsProvider(config: config)
        case .anthropic:
            AnthropicProvider(config: config, apiKey: apiKey, http: http)
        case .google:
            GoogleTranslateProvider(config: config, apiKey: apiKey, http: http, serviceAccount: serviceAccount)
        case .deepl:
            DeepLProvider(config: config, apiKey: apiKey, http: http)
        }
    }
}
