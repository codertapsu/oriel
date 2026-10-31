import Foundation
@testable import OrielTranslation
import Testing

/// Apple Translation of 1,500 characters takes under 1 s for an installed pair (PLAN §9). It runs where a pair from
/// English is installed and downloads nothing (`TranslationSession(installedSource:target:)`). A process's first
/// session loads the model; the budget is for the sessions after it (the median of three), and both are printed.
struct AppleTranslationBudgetTests {
    private static let budget = Duration.seconds(1)
    private static let english = Locale.Language(identifier: "en")
    private static let targets = ["vi", "de", "fr", "es", "it", "pt-BR", "nl", "ja", "ko", "zh-Hans"]

    /// The first target whose pack from English is installed.
    private static func installedTarget() async -> Locale.Language? {
        let backend = SystemTranslationBackend(prefersHighFidelity: false)
        for code in targets {
            let target = Locale.Language(identifier: code)
            if await backend.status(from: english, to: target) == .installed {
                return target
            }
        }
        return nil
    }

    /// Thirteen sentences of interface text, about 1,500 characters, one segment each, as OCR blocks arrive.
    private static let segments: [TranslationSegment] = [
        "Window Switcher shows every open window as a thumbnail, with the most recently used one first.",
        "Hold Option and press Tab to step through the windows, then release the keys to switch to the selected one.",
        "Type while the switcher is open to search window titles and app names at the same time.",
        "Capture Area freezes the screen first, so menus, tooltips and video frames stay where they are.",
        "Translate Area reads the text in the region you select and shows the translation over the original.",
        "Disk Space Analyzer lists the largest folders first and explains what each of them holds.",
        "Clean Up checks a folder before anything is moved to the Trash and recommends the safest way.",
        "Clipboard History keeps the text, images and files you copied, and pasting one takes two keys.",
        "Activity Monitor samples processes only while its window is open, so it costs nothing otherwise.",
        "Screen Ruler measures the distance between edges on any display, in points or in pixels.",
        "Settings sync between your Macs through a folder in iCloud Drive whenever they change.",
        "Every command has a keyboard shortcut, an item in the menu bar and a link you can open.",
        "Press Escape at any time to close a panel without changing anything on the screen.",
    ].enumerated().map { TranslationSegment(id: $0.offset + 1, text: $0.element) }

    @Test(.enabled("needs a language pack from English installed") { await installedTarget() != nil })
    func fifteenHundredCharactersTranslateInsideTheBudget() async throws {
        let target = try #require(await Self.installedTarget())
        let characters = Self.segments.reduce(0) { $0 + $1.text.count }
        #expect((1400 ... 1600).contains(characters))
        let backend = SystemTranslationBackend(prefersHighFidelity: false)
        let clock = ContinuousClock()
        var translated = 0
        let first = try await clock.measure {
            for try await _ in backend.translate(Self.segments, from: Self.english, to: target) {
                translated += 1
            }
        }
        #expect(translated == Self.segments.count)
        var runs: [Duration] = []
        for _ in 0 ..< 3 {
            try await runs.append(clock.measure {
                for try await _ in backend.translate(Self.segments, from: Self.english, to: target) {}
            })
        }
        let median = runs.sorted()[1]
        print("Apple Translation, \(characters) characters, en → \(target.minimalIdentifier): first \(first), median \(median)")
        #expect(median < Self.budget, "median \(median)")
    }
}
