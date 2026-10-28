import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

@MainActor
struct ProviderRegistryTests {
    private func registry(
        _ settings: SettingsStore,
        secrets: InMemorySecrets = InMemorySecrets(),
        appleIntelligence: Bool = true
    ) -> ProviderRegistry {
        ProviderRegistry(
            settings: settings, secrets: secrets, http: HTTPClient(session: StubURLProtocol.session),
            foundationModelsGate: { appleIntelligence ? .open : .closed("Turn on Apple Intelligence.") }
        )
    }

    /// The format of `docs/bootstrap.example.json`, plus an entry of a kind Oriel does not know.
    private let bootstrap = """
    {
      "version": 1,
      "providers": [
        { "id": "ollama", "kind": "openai-compatible", "baseURL": "http://ollama.internal:11434/v1", "model": "qwen2.5:14b", "apiKey": "" },
        { "id": "anthropic", "kind": "anthropic", "model": "<model-id>", "apiKey": "<key>" },
        { "id": "pigeon", "kind": "carrier-pigeon" }
      ],
      "defaultProvider": "apple",
      "upload": { "kind": "s3" }
    }
    """

    private struct BootstrapFile: Decodable {
        let providers: [BootstrapProvider]
        let defaultProvider: String?
    }

    @Test func alwaysHasTheBuiltInProviders() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        settings.store[TranslationKeys.providers] = [ProviderConfig(id: "deepl", kind: .deepl)]
        #expect(registry(settings.store).configs.map(\.id.rawValue) == ["apple", "foundation-models", "deepl"])
    }

    @Test func importsTheBootstrapFile() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        let registry = registry(settings.store, secrets: secrets)
        let file = try JSONDecoder().decode(BootstrapFile.self, from: Data(bootstrap.utf8))
        registry.applyBootstrap(file.providers, defaultProvider: "anthropic")

        #expect(registry.configs.map(\.id.rawValue) == ["apple", "foundation-models", "ollama", "anthropic"])
        let ollama = try #require(registry.config(for: "ollama"))
        #expect(ollama.kind == .openAICompatible && ollama.displayName == "Ollama")
        #expect(ollama.baseURL == "http://ollama.internal:11434/v1" && ollama.model == "qwen2.5:14b")
        let anthropic = try #require(registry.config(for: "anthropic"))
        #expect(anthropic.kind == .anthropic && anthropic.model == "<model-id>" && anthropic.displayName == "Anthropic")
        // Keys go to the secret store only, under provider.<id>; an empty key stores nothing.
        #expect(secrets.string(service: "provider.anthropic", account: "default") == "<key>")
        #expect(secrets.services == ["provider.anthropic"])
        #expect(!String(describing: settings.store[TranslationKeys.providers]).contains("<key>"))
        #expect(settings.store[TranslationKeys.defaultProvider] == "anthropic")
    }

    @Test func importingAgainUpdatesProvidersInPlace() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let registry = registry(settings.store)
        registry.applyBootstrap([BootstrapProvider(id: "ollama", kind: "openai-compatible", model: "a")], defaultProvider: nil)
        var edited = try #require(registry.config(for: "ollama"))
        edited.temperature = 0.4
        edited.isEnabled = false
        registry.update(edited)
        registry.applyBootstrap([BootstrapProvider(id: "ollama", kind: "openai-compatible", model: "b")], defaultProvider: "nope")
        let ollama = try #require(registry.config(for: "ollama"))
        #expect(ollama.model == "b" && ollama.temperature == 0.4 && ollama.isEnabled)
        #expect(registry.configs.count { $0.id == "ollama" } == 1)
        #expect(settings.store[TranslationKeys.defaultProvider] == "apple")
    }

    @Test func remembersTheProviderLastUsedForEachTarget() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let registry = registry(settings.store)
        registry.add(.deepl)
        #expect(registry.preferredProvider(forTarget: "ja") == .apple)
        registry.remember("deepl", forTarget: "ja")
        #expect(registry.preferredProvider(forTarget: "ja") == "deepl")
        #expect(registry.preferredProvider(forTarget: "fr") == .apple)
        settings.store[TranslationKeys.defaultProvider] = "deepl"
        #expect(registry.preferredProvider(forTarget: "fr") == "deepl")
        var deepl = try #require(registry.config(for: "deepl"))
        deepl.isEnabled = false
        registry.update(deepl)
        #expect(registry.preferredProvider(forTarget: "ja") == .apple)
    }

    @Test func hidesAppleIntelligenceWhenItIsUnavailable() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        #expect(registry(settings.store).selectableConfigs.map(\.id) == [.apple, .foundationModels])
        let hidden = registry(settings.store, appleIntelligence: false)
        #expect(hidden.selectableConfigs.map(\.id) == [.apple])
        settings.store[TranslationKeys.defaultProvider] = ProviderID.foundationModels.rawValue
        #expect(hidden.preferredProvider(forTarget: "en") == .apple)
        #expect(!hidden.appleHighFidelity)
    }

    @Test func addsPresetsWithUniqueIDsAndRemovesProvidersWithTheirKeys() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        let registry = registry(settings.store, secrets: secrets)
        let first = registry.add(.ollama)
        let second = registry.add(.ollama)
        #expect(first.id == "ollama" && second.id == "ollama-2")
        #expect(first.baseURL == "http://localhost:11434/v1" && first.model.isEmpty)
        try registry.setAPIKey("  sk-1  ", for: second.id)
        #expect(registry.apiKey(for: second.id)?.value == "sk-1")
        registry.remove(second.id)
        #expect(registry.config(for: second.id) == nil && secrets.services.isEmpty)
        registry.remove(.apple)
        #expect(registry.config(for: .apple) != nil)
    }

    @Test func apiKeysNeverAppearInDescriptions() throws {
        let key = try #require(APIKey("sk-secret-123"))
        var dumped = ""
        dump(key, to: &dumped)
        for text in ["\(key)", String(describing: key), String(reflecting: key), dumped] {
            #expect(!text.contains("sk-secret-123"))
        }
        let provider = OpenAICompatibleProvider(
            config: ProviderConfig(id: "openai", kind: .openAICompatible), apiKey: key, http: HTTPClient(session: StubURLProtocol.session)
        )
        var dumpedProvider = ""
        dump(provider, to: &dumpedProvider)
        #expect(!dumpedProvider.contains("sk-secret-123") && !String(describing: provider).contains("sk-secret-123"))
        #expect(APIKey("   ") == nil && APIKey(nil) == nil)
    }

    @Test func readsProviderSettingsSavedByAnOlderVersion() throws {
        let stored = #"[{"id":"deepl","kind":"deepl","displayName":"DeepL Pro"}]"#
        let configs = try JSONDecoder().decode([ProviderConfig].self, from: Data(stored.utf8))
        let deepl = try #require(configs.first)
        #expect(deepl.displayName == "DeepL Pro" && deepl.isEnabled && deepl.timeoutSeconds == 60 && deepl.formality == .automatic)
        #expect(deepl.effectiveBaseURL == "https://api.deepl.com")
        #expect(deepl.glossaryResource.isEmpty)
    }

    /// Google glossaries need a service account key (PLAN §7.7.2): it is checked, kept beside the API key, handed to
    /// the provider and removed with it, and never printed.
    @Test func serviceAccountKeysAreCheckedStoredAndRemovedWithTheProvider() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let secrets = InMemorySecrets()
        let registry = registry(settings.store, secrets: secrets)
        let google = registry.add(.google)
        #expect(throws: TranslationFailure.self) { try registry.setServiceAccount(json: "{}", for: google.id) }
        #expect(secrets.services.isEmpty)

        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.googleapis.com/token")
        let account = try #require(try registry.setServiceAccount(json: made.json, for: google.id))
        #expect(registry.serviceAccount(for: google.id)?.clientEmail == account.clientEmail)
        #expect(secrets.string(service: google.id.keychainService, account: "serviceAccount") == made.json)
        let provider = try #require(registry.provider(for: google.id) as? GoogleTranslateProvider)
        #expect(provider.serviceAccount?.clientEmail == account.clientEmail)
        var dumped = ""
        dump(provider, to: &dumped)
        #expect(!dumped.contains("PRIVATE KEY") && !String(describing: provider).contains("PRIVATE KEY"))

        registry.remove(google.id)
        #expect(secrets.services.isEmpty)
    }

    @Test func bootstrapImportsAGlossaryAndAServiceAccountKeyGivenAsAnObjectOrAString() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let registry = registry(settings.store)
        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.googleapis.com/token")
        let entry = #"{"id": "google", "kind": "google", "glossary": "terms", "serviceAccountKey": \#(made.json)}"#
        try registry.applyBootstrap([JSONDecoder().decode(BootstrapProvider.self, from: Data(entry.utf8))], defaultProvider: nil)
        #expect(registry.config(for: "google")?.glossaryResource == "terms")
        #expect(registry.serviceAccount(for: "google")?.clientEmail == "oriel@test-project.iam.gserviceaccount.com")
        #expect(!String(describing: settings.store[TranslationKeys.providers]).contains("PRIVATE KEY"))

        let quoted = try JSONEncoder().encode(BootstrapServiceAccountKey(json: made.json))
        let fromString = try JSONDecoder().decode(BootstrapServiceAccountKey.self, from: quoted)
        #expect(try GoogleServiceAccount(json: fromString.json).clientEmail == "oriel@test-project.iam.gserviceaccount.com")
    }
}
