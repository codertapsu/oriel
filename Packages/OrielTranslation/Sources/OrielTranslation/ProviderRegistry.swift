import Foundation
import OrielCore

/// The configured providers: their settings, their Keychain keys, which one to use for a target language, and the
/// bootstrap import (PLAN §7.7.5).
@MainActor
final class ProviderRegistry {
    typealias ProviderOverride = @MainActor (ProviderConfig) -> (any TranslationProvider)?

    private let settings: SettingsStore
    private let secrets: any SecretStore
    private let factory: ProviderFactory
    private let override: ProviderOverride?
    private let foundationModelsGate: @MainActor () -> FeatureGate
    private let log = Log.logger("translation")
    private static let keyAccount = "default"
    /// The Google service account key file, under the same service as the API key.
    private static let serviceAccountAccount = "serviceAccount"

    /// `override` lets tests substitute providers; `foundationModelsGate` decides whether Apple Intelligence is shown.
    init(
        settings: SettingsStore,
        secrets: any SecretStore,
        http: HTTPClient,
        override: ProviderOverride? = nil,
        foundationModelsGate: @escaping @MainActor () -> FeatureGate = { FoundationModelsProvider.gate }
    ) {
        self.settings = settings
        self.secrets = secrets
        deepLGlossaries = DeepLGlossaryBook(records: settings[TranslationKeys.deepLGlossaries]) { records in
            await MainActor.run { settings[TranslationKeys.deepLGlossaries] = records }
        }
        factory = ProviderFactory(http: http, deepLGlossaries: deepLGlossaries)
        self.override = override
        self.foundationModelsGate = foundationModelsGate
    }

    /// The DeepL glossaries made for glossary projects, kept in settings.
    let deepLGlossaries: DeepLGlossaryBook

    /// Deletes the DeepL glossaries of a deleted glossary project, as far as DeepL lets it; a glossary that cannot be
    /// deleted now stays in the account, where it does no harm.
    func deleteDeepLGlossaries(ofProject projectID: UUID) {
        let book = deepLGlossaries
        let providers = configs.filter { $0.kind == .deepl }.compactMap { provider(for: $0) as? DeepLProvider }
        Task {
            for item in await book.removeRecords(forProject: projectID) {
                let providerID = item.key.split(separator: "|").first.map(String.init)
                guard let provider = providers.first(where: { $0.config.id.rawValue == providerID }) else { continue }
                try? await provider.deleteGlossary(item.record.glossaryID)
            }
        }
    }

    /// Every configured provider, in Settings order, with the built-in ones always present.
    var configs: [ProviderConfig] {
        var configs = settings[TranslationKeys.providers]
        for (index, builtIn) in ProviderConfig.builtIns.enumerated() where !configs.contains(where: { $0.id == builtIn.id }) {
            configs.insert(builtIn, at: min(index, configs.count))
        }
        return configs
    }

    /// The providers the user can pick: enabled, and not hidden by a closed gate. ⌘1…⌘9 follow this order.
    var selectableConfigs: [ProviderConfig] {
        configs.filter { $0.isEnabled && isVisible($0) }
    }

    /// Apple Intelligence is hidden, not just disabled, when the system model is unavailable (PLAN rule 5).
    func isVisible(_ config: ProviderConfig) -> Bool {
        config.kind != .foundationModels || foundationModelsGate().isOpen
    }

    func config(for id: ProviderID) -> ProviderConfig? {
        configs.first { $0.id == id }
    }

    func provider(for id: ProviderID) -> (any TranslationProvider)? {
        config(for: id).map(provider(for:))
    }

    func provider(for config: ProviderConfig) -> any TranslationProvider {
        if let override, let provider = override(config) {
            return provider
        }
        return factory.make(
            config,
            apiKey: apiKey(for: config.id),
            serviceAccount: config.kind == .google ? serviceAccount(for: config.id) : nil,
            appleHighFidelity: appleHighFidelity
        )
    }

    /// Apple Translation's high-fidelity strategy: wanted by the user and possible (Apple Intelligence available).
    var appleHighFidelity: Bool {
        settings[TranslationKeys.appleHighFidelity] && foundationModelsGate().isOpen
    }

    // MARK: - Keys

    func apiKey(for id: ProviderID) -> APIKey? {
        APIKey(secrets.string(service: id.keychainService, account: Self.keyAccount))
    }

    func hasAPIKey(_ id: ProviderID) -> Bool {
        apiKey(for: id) != nil
    }

    /// Saves the key in the Keychain, or deletes it for nil or an empty string.
    func setAPIKey(_ value: String?, for id: ProviderID) throws {
        try secrets.setString(APIKey(value)?.value, service: id.keychainService, account: Self.keyAccount)
    }

    /// The Google service account key stored for `id`; nil when there is none or it no longer reads.
    func serviceAccount(for id: ProviderID) -> GoogleServiceAccount? {
        secrets.string(service: id.keychainService, account: Self.serviceAccountAccount).flatMap { try? GoogleServiceAccount(json: $0) }
    }

    /// Checks a key file and stores it in the Keychain (nil deletes it). Throws, storing nothing, for a file that is
    /// not a usable service account key.
    @discardableResult
    func setServiceAccount(json: String?, for id: ProviderID) throws -> GoogleServiceAccount? {
        let account = try json.map(GoogleServiceAccount.init(json:))
        try secrets.setString(account?.json, service: id.keychainService, account: Self.serviceAccountAccount)
        return account
    }

    // MARK: - Choosing

    /// The provider last used for this target language, else the default, else the first selectable one.
    func preferredProvider(forTarget target: String) -> ProviderID {
        let selectable = selectableConfigs.map(\.id)
        if let last = settings[TranslationKeys.lastProviderByTarget][target].map(ProviderID.init(rawValue:)), selectable.contains(last) {
            return last
        }
        let preferred = ProviderID(rawValue: settings[TranslationKeys.defaultProvider])
        if selectable.contains(preferred) {
            return preferred
        }
        return selectable.first ?? .apple
    }

    func remember(_ id: ProviderID, forTarget target: String) {
        var last = settings[TranslationKeys.lastProviderByTarget]
        guard last[target] != id.rawValue else { return }
        last[target] = id.rawValue
        settings[TranslationKeys.lastProviderByTarget] = last
    }

    // MARK: - Editing

    func update(_ config: ProviderConfig) {
        var configs = configs
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        settings[TranslationKeys.providers] = configs
    }

    /// Adds a provider from a preset, with an id that is not taken yet.
    @discardableResult
    func add(_ preset: ProviderPreset) -> ProviderConfig {
        let id = uniqueID(preset.suggestedID)
        let config = ProviderConfig(id: id, kind: preset.kind, displayName: preset.title, baseURL: preset.baseURL)
        update(config)
        return config
    }

    /// Removes a provider and its key. Built-in providers can only be disabled.
    func remove(_ id: ProviderID) {
        guard let config = config(for: id), !config.isBuiltIn else { return }
        settings[TranslationKeys.providers] = configs.filter { $0.id != id }
        do {
            try setAPIKey(nil, for: id)
            try setServiceAccount(json: nil, for: id)
        } catch {
            log.error("Couldn't delete the key of \(id.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Bootstrap

    /// Imports providers from the shared config: settings into `SettingsStore`, keys into the Keychain. Existing
    /// providers with the same id are updated; fields the file leaves out keep their values.
    func applyBootstrap(_ providers: [BootstrapProvider], defaultProvider: String?) {
        var configs = configs
        for entry in providers {
            let rawID = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawID.isEmpty, let kind = ProviderKind(rawValue: entry.kind.trimmingCharacters(in: .whitespaces).lowercased()) else {
                log.error("Bootstrap: skipped a provider with an unknown kind “\(entry.kind, privacy: .public)” or no id")
                continue
            }
            let id = ProviderID(rawValue: rawID)
            let index = configs.firstIndex { $0.id == id }
            var config = index.map { configs[$0] }
                ?? ProviderConfig(id: id, kind: kind, displayName: ProviderPreset.displayName(forID: rawID, kind: kind))
            config.kind = kind
            config.isEnabled = true
            config.baseURL = entry.baseURL ?? config.baseURL
            config.model = entry.model ?? config.model
            config.displayName = entry.displayName ?? config.displayName
            config.temperature = entry.temperature ?? config.temperature
            config.timeoutSeconds = entry.timeoutSeconds ?? config.timeoutSeconds
            config.customHeaders = entry.headers ?? config.customHeaders
            config.formality = entry.formality.flatMap(ProviderConfig.Formality.init(rawValue:)) ?? config.formality
            config.glossaryResource = entry.glossary ?? config.glossaryResource
            if let index {
                configs[index] = config
            } else {
                configs.append(config)
            }
            if let key = APIKey(entry.apiKey) {
                do {
                    try setAPIKey(key.value, for: id)
                } catch {
                    let reason = error.localizedDescription
                    log.error("Bootstrap: couldn't store the key of \(rawID, privacy: .public): \(reason, privacy: .public)")
                }
            }
            if let file = entry.serviceAccountKey {
                do {
                    try setServiceAccount(json: file.json, for: id)
                } catch {
                    let reason = error.localizedDescription
                    log.error("Bootstrap: couldn't store the service account of \(rawID, privacy: .public): \(reason, privacy: .public)")
                }
            }
        }
        settings[TranslationKeys.providers] = configs
        let chosen = defaultProvider?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let chosen, configs.contains(where: { $0.id.rawValue == chosen }) {
            settings[TranslationKeys.defaultProvider] = chosen
        }
        log.info("Bootstrap: imported \(providers.count) translation providers")
    }

    private func uniqueID(_ base: String) -> ProviderID {
        let taken = Set(configs.map(\.id.rawValue))
        guard taken.contains(base) else { return ProviderID(rawValue: base) }
        var number = 2
        while taken.contains("\(base)-\(number)") {
            number += 1
        }
        return ProviderID(rawValue: "\(base)-\(number)")
    }
}
