import OrielCore

/// Clipboard History's settings, all named `clipboard.*` (Settings → Clipboard History).
nonisolated enum ClipboardSettings {
    static let prefix = "clipboard."

    /// While paused nothing is kept, not even Oriel's own copies.
    static let isPaused = SettingKey("clipboard.isPaused", default: false)
    /// Take an item out of the history once it has been pasted. Pinned items always stay.
    static let removesAfterPaste = SettingKey("clipboard.removesAfterPaste", default: false)
    /// Return pastes text without its formatting, and ⌥Return with it; off, the other way round.
    static let pastesPlainText = SettingKey("clipboard.pastesPlainText", default: false)
    /// The most history items kept; pinned items do not count.
    static let itemLimit = SettingKey("clipboard.itemLimit", default: 500)
    /// Days to keep history items; 0 keeps them until the limit pushes them out. Pinned items never expire.
    static let retentionDays = SettingKey("clipboard.retentionDays", default: 30)
    /// The most the history takes on disk, in megabytes of 1,000,000 bytes as Finder counts them; the oldest history
    /// items go first. Every screenshot is copied, so without it a few hundred captures would fill gigabytes.
    static let maxMegabytes = SettingKey("clipboard.maxMegabytes", default: 500)
    /// Bundle IDs of apps whose copies are never kept.
    static let ignoredApps = SettingKey("clipboard.ignoredApps", default: PrivacyFilter.defaultIgnoredApps)
    /// Whether Oriel has already opened Paste from Other Apps after macOS first asked about it.
    static let openedPasteboardSettings = SettingKey("clipboard.openedPasteboardSettings", default: false)

    static let itemLimitChoices = [100, 200, 500, 1000, 2000]
    static let retentionChoices = [1, 7, 30, 90, 0]
    static let megabyteChoices = [100, 250, 500, 1000, 2000, 5000]

    /// The settings that `limits(in:)` reads, so a change to any of them prunes at once.
    static let limitNames: Set<String> = [itemLimit.name, retentionDays.name, maxMegabytes.name]

    @MainActor
    static func limits(in settings: SettingsStore) -> ClipboardLimits {
        ClipboardLimits(items: settings[itemLimit], days: settings[retentionDays], bytes: settings[maxMegabytes] * 1_000_000)
    }
}
