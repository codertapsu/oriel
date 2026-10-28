import Foundation
import OrielCore

/// Counts characters and tokens per provider and calendar month (PLAN §7.7.2) and enforces the optional monthly cap.
/// A new month starts from zero; nothing runs in the background, the month is compared when a count is read or
/// written.
@MainActor
final class UsageTracker {
    private let settings: SettingsStore
    private let now: @MainActor () -> Date

    init(settings: SettingsStore, now: @escaping @MainActor () -> Date = { Date() }) {
        self.settings = settings
        self.now = now
    }

    func record(_ usage: TranslationUsage, for provider: ProviderID) {
        var all = settings[TranslationKeys.usage]
        var entry = current(all[provider.rawValue])
        entry.characters += usage.characters
        entry.inputTokens += usage.inputTokens
        entry.outputTokens += usage.outputTokens
        entry.requests += 1
        all[provider.rawValue] = entry
        settings[TranslationKeys.usage] = all
    }

    /// This month's usage of a provider (zero when it has none yet this month).
    func usage(for provider: ProviderID) -> ProviderUsage {
        current(settings[TranslationKeys.usage][provider.rawValue])
    }

    func isOverCap(_ config: ProviderConfig) -> Bool {
        guard let cap = config.monthlyCap, cap > 0 else { return false }
        return usage(for: config.id).measure(countsTokens: config.kind.countsTokens) >= cap
    }

    func reset(_ provider: ProviderID) {
        var all = settings[TranslationKeys.usage]
        all[provider.rawValue] = nil
        settings[TranslationKeys.usage] = all
    }

    private var monthKey: String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now())
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func current(_ stored: ProviderUsage?) -> ProviderUsage {
        guard let stored, stored.month == monthKey else { return ProviderUsage(month: monthKey) }
        return stored
    }
}
