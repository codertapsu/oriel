import Foundation
import Observation
import OrielCore
import SwiftUI

/// State and actions behind Settings → Translation: provider editing, API keys (Keychain only), "Fetch models",
/// "Test connection", usage counters and caps, glossary and history settings.
@MainActor
@Observable
final class TranslationSettingsModel {
    enum TestState: Equatable {
        case running
        case succeeded(String)
        case failed(String)
    }

    let settings: SettingsStore
    let registry: ProviderRegistry
    let usage: UsageTracker
    let openHistory: @MainActor () -> Void
    let clearHistory: @MainActor () async -> Void

    var tests: [ProviderID: TestState] = [:]
    var fetchedModels: [ProviderID: [String]] = [:]
    var keyDrafts: [ProviderID: String] = [:]
    var keyMessages: [ProviderID: String] = [:]
    var headerDrafts: [ProviderID: String] = [:]
    var glossaryDraft: String
    var showsLanguagePackSheet = false
    /// Whether the Keychain has a key, cached so views do not query it on every update. Not observed: it is filled
    /// while views read it, and every change to it also changes `keyMessages`.
    @ObservationIgnored private var storedKeys: [ProviderID: Bool] = [:]
    /// The Google service account's address per provider, cached the same way.
    @ObservationIgnored private var serviceAccountEmails: [ProviderID: String?] = [:]

    init(
        settings: SettingsStore,
        registry: ProviderRegistry,
        usage: UsageTracker,
        openHistory: @escaping @MainActor () -> Void,
        clearHistory: @escaping @MainActor () async -> Void
    ) {
        self.settings = settings
        self.registry = registry
        self.usage = usage
        self.openHistory = openHistory
        self.clearHistory = clearHistory
        glossaryDraft = Self.text(from: settings[TranslationKeys.glossary], separator: " = ")
    }

    /// Providers shown in Settings: every configured one except those hidden by a closed gate.
    var configs: [ProviderConfig] {
        registry.configs.filter(registry.isVisible)
    }

    var selectableConfigs: [ProviderConfig] {
        registry.selectableConfigs
    }

    /// Why Apple Intelligence is not listed, when it is not.
    var hiddenProviderNote: String? {
        let gate = FoundationModelsProvider.gate
        return gate.isOpen ? nil : "Apple Intelligence isn't listed: \(gate.reason ?? "unavailable")."
    }

    /// The high-fidelity toggle exists only where it can do something (macOS 26.4+, Apple Intelligence available).
    var offersHighFidelity: Bool {
        SystemTranslationBackend.strategyGate.isOpen && FoundationModelsProvider.gate.isOpen
    }

    func binding(for id: ProviderID) -> Binding<ProviderConfig> {
        let fallback = registry.config(for: id) ?? ProviderConfig(id: id, kind: .openAICompatible)
        return Binding(
            get: { [registry] in registry.config(for: id) ?? fallback },
            set: { [registry] in registry.update($0) }
        )
    }

    // MARK: - Keys

    func hasKey(_ id: ProviderID) -> Bool {
        if let known = storedKeys[id] {
            return known
        }
        let stored = registry.hasAPIKey(id)
        storedKeys[id] = stored
        return stored
    }

    func saveKey(for id: ProviderID) {
        let draft = keyDrafts[id] ?? ""
        do {
            try registry.setAPIKey(draft, for: id)
            storedKeys[id] = APIKey(draft) != nil
            keyDrafts[id] = ""
            keyMessages[id] = APIKey(draft) == nil ? "Key removed." : "Saved in the Keychain."
        } catch {
            keyMessages[id] = "Couldn't save the key: \(error.localizedDescription)"
        }
    }

    func deleteKey(for id: ProviderID) {
        keyDrafts[id] = ""
        saveKey(for: id)
    }

    /// PLAN §7.7.7, §11: a model running on an Intel Mac is impractically slow, so its settings say so.
    func localModelWarning(for config: ProviderConfig) -> String? {
        Self.localModelWarning(for: config, isAppleSilicon: HardwareInfo.isAppleSiliconHardware)
    }

    /// The warning for a model server on this Mac (a loopback endpoint) when the Mac has an Intel processor.
    nonisolated static func localModelWarning(for config: ProviderConfig, isAppleSilicon: Bool) -> String? {
        guard !isAppleSilicon, config.kind == .openAICompatible, Endpoint.isLocal(config.effectiveBaseURL) else { return nil }
        return "This Mac has an Intel processor, so a model running on it is very slow. Apple Translation, or a model server "
            + "on another Mac, is much faster."
    }

    // MARK: - Google service account (glossaries)

    /// The stored service account's address, or nil when there is none.
    func serviceAccountEmail(_ id: ProviderID) -> String? {
        if let known = serviceAccountEmails[id] {
            return known
        }
        let email = registry.serviceAccount(for: id)?.clientEmail
        serviceAccountEmails[id] = .some(email)
        return email
    }

    /// Checks the key file the user picked and stores it in the Keychain; the file itself is left where it is.
    func importServiceAccount(from url: URL, for id: ProviderID) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let account = try registry.setServiceAccount(json: String(contentsOf: url, encoding: .utf8), for: id)
            serviceAccountEmails[id] = .some(account?.clientEmail)
            keyMessages[id] = "Service account key saved in the Keychain."
        } catch {
            keyMessages[id] = "Couldn't use that key file: \(TranslationFailure.from(error).localizedDescription)"
        }
    }

    func removeServiceAccount(for id: ProviderID) {
        do {
            try registry.setServiceAccount(json: nil, for: id)
            serviceAccountEmails[id] = .some(nil)
            keyMessages[id] = "Service account key removed."
        } catch {
            keyMessages[id] = "Couldn't remove the key: \(error.localizedDescription)"
        }
    }

    // MARK: - Server checks

    func test(_ id: ProviderID) {
        guard let provider = registry.provider(for: id) else { return }
        tests[id] = .running
        Task {
            do {
                tests[id] = try await .succeeded(provider.testConnection())
            } catch {
                tests[id] = .failed(TranslationFailure.from(error).localizedDescription)
            }
        }
    }

    func canFetchModels(_ config: ProviderConfig) -> Bool {
        config.kind == .openAICompatible || config.kind == .anthropic
    }

    func fetchModels(_ id: ProviderID) {
        guard let lister = registry.provider(for: id) as? any ModelListing else { return }
        tests[id] = .running
        Task {
            do {
                let models = try await lister.listModels()
                fetchedModels[id] = models
                tests[id] = .succeeded(models.isEmpty ? "The server lists no models." : "Found \(models.count) models.")
            } catch {
                tests[id] = .failed(TranslationFailure.from(error).localizedDescription)
            }
        }
    }

    // MARK: - Providers

    func add(_ preset: ProviderPreset) {
        registry.add(preset)
    }

    func remove(_ id: ProviderID) {
        registry.remove(id)
        tests[id] = nil
        storedKeys[id] = nil
    }

    func headerText(for config: ProviderConfig) -> Binding<String> {
        Binding(
            get: { [self] in headerDrafts[config.id] ?? Self.text(from: config.customHeaders, separator: ": ") },
            set: { [self] text in
                headerDrafts[config.id] = text
                var updated = registry.config(for: config.id) ?? config
                updated.customHeaders = Self.pairs(from: text, separator: ":")
                registry.update(updated)
            }
        )
    }

    var glossary: Binding<String> {
        Binding(
            get: { [self] in glossaryDraft },
            set: { [self] text in
                glossaryDraft = text
                settings[TranslationKeys.glossary] = Self.pairs(from: text, separator: "=")
            }
        )
    }

    // MARK: - Usage

    func usageText(for config: ProviderConfig) -> String {
        let used = usage.usage(for: config.id)
        let figure = config.kind.countsTokens
            ? "\(used.tokens.formatted()) tokens, \(used.characters.formatted()) characters"
            : "\(used.characters.formatted()) characters"
        return "This month: \(figure) in \(used.requests.formatted()) translations"
    }

    func resetUsage(_ id: ProviderID) {
        usage.reset(id)
    }

    // MARK: - Text fields of pairs

    /// One `key<separator>value` per line, in key order.
    static func text(from pairs: [String: String], separator: String) -> String {
        pairs.sorted { $0.key < $1.key }.map { "\($0.key)\(separator)\($0.value)" }.joined(separator: "\n")
    }

    /// Parses `key<separator>value` lines, ignoring blank and malformed ones.
    static func pairs(from text: String, separator: Character) -> [String: String] {
        var pairs: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let index = line.firstIndex(of: separator) else { continue }
            let key = line[..<index].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                pairs[key] = value
            }
        }
        return pairs
    }
}
