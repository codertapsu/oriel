import Foundation
@testable import OrielTranslation
import Testing

@MainActor
struct UsageTrackerTests {
    /// The tracker's clock, movable between calls.
    private final class Clock {
        var now: Date

        init(_ now: Date) {
            self.now = now
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    @Test func countsPerProviderAndStartsAgainEachMonth() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let clock = try Clock(date(2026, 10, 30))
        let tracker = UsageTracker(settings: settings.store) { clock.now }
        tracker.record(TranslationUsage(characters: 100, inputTokens: 10, outputTokens: 5), for: "deepl")
        tracker.record(TranslationUsage(characters: 50), for: "deepl")
        #expect(tracker.usage(for: "deepl") == ProviderUsage(
            month: "2026-10",
            characters: 150,
            inputTokens: 10,
            outputTokens: 5,
            requests: 2
        ))
        #expect(tracker.usage(for: "google") == ProviderUsage(month: "2026-10"))

        clock.now = try date(2026, 11, 1)
        #expect(tracker.usage(for: "deepl") == ProviderUsage(month: "2026-11"))
        tracker.record(TranslationUsage(characters: 7), for: "deepl")
        #expect(tracker.usage(for: "deepl").characters == 7)
        // A second tracker reads the same stored counters.
        #expect(UsageTracker(settings: settings.store) { clock.now }.usage(for: "deepl").requests == 1)
    }

    @Test func capsCountCharactersForTranslationServicesAndTokensForModels() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let tracker = UsageTracker(settings: settings.store)
        tracker.record(TranslationUsage(characters: 900, inputTokens: 40, outputTokens: 30), for: "deepl")
        tracker.record(TranslationUsage(characters: 900, inputTokens: 40, outputTokens: 30), for: "openai")
        #expect(tracker.isOverCap(ProviderConfig(id: "deepl", kind: .deepl, monthlyCap: 900)))
        #expect(!tracker.isOverCap(ProviderConfig(id: "deepl", kind: .deepl, monthlyCap: 901)))
        #expect(!tracker.isOverCap(ProviderConfig(id: "openai", kind: .openAICompatible, monthlyCap: 100)))
        #expect(tracker.isOverCap(ProviderConfig(id: "openai", kind: .openAICompatible, monthlyCap: 70)))
        #expect(!tracker.isOverCap(ProviderConfig(id: "deepl", kind: .deepl)))
        tracker.reset("deepl")
        #expect(tracker.usage(for: "deepl").characters == 0)
    }
}
