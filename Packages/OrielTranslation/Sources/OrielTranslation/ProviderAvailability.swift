/// Whether a provider can translate right now, and if not, why and what the user can do about it (PLAN §7.7.1).
public enum ProviderAvailability: Sendable, Equatable {
    case available
    /// The provider needs an API key and the Keychain has none.
    case missingAPIKey
    /// Something in the configuration is missing or wrong (no endpoint, no model). The message says what.
    case notConfigured(String)
    /// The source language could not be detected, and the provider needs it (Apple Translation).
    case sourceLanguageUnknown
    /// Apple Translation supports the pair, but its language pack is not on this Mac yet.
    case packNotInstalled(source: String, target: String)
    case unsupportedLanguagePair(source: String, target: String)
    /// The Mac has no network connection and the provider needs one.
    case offline
    /// The OS, the hardware or a system setting rules the provider out (for example Apple Intelligence is off).
    case unavailable(String)
    /// The provider's monthly usage cap has been reached.
    case capReached

    /// What the user can do about an unavailable provider.
    public enum Action: Sendable, Equatable {
        case downloadLanguagePack
        case addAPIKey
        case openSettings
        case chooseAnotherProvider
    }

    public var isAvailable: Bool {
        self == .available
    }

    /// A short explanation for the toolbar, the side panel and Settings.
    public var message: String {
        switch self {
        case .available: "Ready"
        case .missingAPIKey: "Add an API key in Settings → Translation."
        case let .notConfigured(detail): detail
        case .sourceLanguageUnknown: "Couldn't tell which language the text is in. Choose the source language."
        case let .packNotInstalled(source, target):
            "The language pack for \(LanguageCatalog.name(of: source)) → \(LanguageCatalog.name(of: target)) isn't downloaded yet."
        case let .unsupportedLanguagePair(source, target):
            "\(LanguageCatalog.name(of: source)) → \(LanguageCatalog.name(of: target)) isn't supported by this provider."
        case .offline: "You're offline. On-device and local providers still work."
        case let .unavailable(reason): reason
        case .capReached: "This provider's monthly usage cap is reached."
        }
    }

    /// An SF Symbol for the state.
    public var symbol: String {
        switch self {
        case .available: "checkmark.circle"
        case .missingAPIKey: "key"
        case .notConfigured: "gearshape"
        case .sourceLanguageUnknown: "questionmark.circle"
        case .packNotInstalled: "arrow.down.circle"
        case .unsupportedLanguagePair: "nosign"
        case .offline: "wifi.slash"
        case .unavailable: "exclamationmark.triangle"
        case .capReached: "gauge.with.dots.needle.100percent"
        }
    }

    /// The fix the UI offers, if there is one.
    public var action: Action? {
        switch self {
        case .available: nil
        case .packNotInstalled: .downloadLanguagePack
        case .missingAPIKey: .addAPIKey
        case .notConfigured, .capReached: .openSettings
        case .sourceLanguageUnknown, .unsupportedLanguagePair, .offline, .unavailable: .chooseAnotherProvider
        }
    }

    /// The error a translation attempt reports when the provider is in this state.
    var failure: TranslationFailure? {
        switch self {
        case .available: nil
        case .missingAPIKey: .missingAPIKey
        case let .notConfigured(detail): .notConfigured(detail)
        case .sourceLanguageUnknown: .sourceLanguageUnknown
        case let .packNotInstalled(source, target): .packNotInstalled(source: source, target: target)
        case let .unsupportedLanguagePair(source, target): .unsupportedLanguagePair(source: source, target: target)
        case .offline: .offline
        case let .unavailable(reason): .unavailable(reason)
        case .capReached: .capReached
        }
    }
}
