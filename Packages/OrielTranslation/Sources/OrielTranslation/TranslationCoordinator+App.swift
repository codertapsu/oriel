import OrielCore

/// What the app shell needs to know about translation without reaching into its settings.
public extension TranslationCoordinator {
    /// The Keychain services that hold provider API keys, for Settings → Advanced → Uninstall.
    var keychainServices: [String] {
        settings[TranslationKeys.providers].map(\.id.keychainService)
    }

    /// Where translations go: the configured language, else the system language, as a BCP 47 code.
    var defaultTargetCode: String {
        LanguageCatalog.code(for: LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage]))
    }
}
