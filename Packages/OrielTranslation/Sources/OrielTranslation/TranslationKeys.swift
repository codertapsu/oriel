import OrielCore

/// Translation's settings (PLAN §7.7.5). Language settings hold BCP 47 codes; an empty code means "the system
/// language" for the target and "detect it" for the source.
enum TranslationKeys {
    static let providers = SettingKey("translation.providers", default: ProviderConfig.builtIns)
    static let defaultProvider = SettingKey("translation.defaultProvider", default: ProviderID.apple.rawValue)
    static let targetLanguage = SettingKey("translation.targetLanguage", default: "")
    static let sourceLanguage = SettingKey("translation.sourceLanguage", default: "")
    /// Target language code → provider id, so each target remembers the provider last used for it.
    static let lastProviderByTarget = SettingKey("translation.lastProviderByTarget", default: [String: String]())
    /// Apple Translation's high-fidelity strategy when Apple Intelligence is available (macOS 26.4+).
    static let appleHighFidelity = SettingKey("translation.apple.highFidelity", default: true)
    /// The one list of terms before glossary projects; moved into a project called "Glossary" on first load.
    static let legacyGlossary = SettingKey("translation.glossary", default: [String: String]())
    /// The id of the glossary project translations use; empty for none. The projects are in `GlossaryStore`.
    static let activeGlossary = SettingKey("translation.glossary.activeProject", default: "")
    /// DeepL glossaries Oriel created, by provider, project and language pair (`DeepLGlossaryBook`).
    static let deepLGlossaries = SettingKey("translation.deepl.glossaries", default: [String: DeepLGlossaryRecord]())
    /// History is opt-in (PLAN §7.7.6).
    static let historyEnabled = SettingKey("translation.history.enabled", default: false)
    /// Days to keep history entries; 0 keeps them until deleted.
    static let historyRetentionDays = SettingKey("translation.history.retentionDays", default: 30)
    /// Provider id → this month's usage.
    static let usage = SettingKey("translation.usage", default: [String: ProviderUsage]())
}
