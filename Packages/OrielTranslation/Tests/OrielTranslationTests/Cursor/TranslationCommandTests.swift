import CoreGraphics
import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

/// The commands translation offers the app, and what Translate Under Cursor asks of the coordinator. Starting the
/// mode for real would put an icon in the menu bar and watch the pointer, so only the refusal is run here.
@MainActor
struct TranslationCommandTests {
    private final class Counter {
        var count = 0
    }

    private func coordinator(_ settings: SettingsStore, provider: FakeProvider? = nil) -> TranslationCoordinator {
        TranslationCoordinator(
            settings: settings,
            secrets: InMemorySecrets(),
            textRecognizer: FakeTextRecognizer([]),
            http: HTTPClient(session: StubURLProtocol.session),
            historyDirectory: FileManager.default.temporaryDirectory.appending(path: "oriel-history-\(UUID().uuidString)"),
            providerOverride: { config in config.id == .apple ? provider : nil },
            foundationModelsGate: { .open }
        )
    }

    @Test func commandsHaveTheirIdsShortcutsAndRoutes() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let commands = coordinator(settings.store).commands
        #expect(commands.map(\.id) == ["translateUnderCursor", "translateFile"])
        #expect(commands.allSatisfy { $0.group == .translation && $0.showsInMenu })
        #expect(commands[0].title == "Translate Under Cursor" && commands[0].route == "translate/cursor")
        #expect(commands[0].defaultShortcut == KeyCombo(keyCode: KeyCode.ansiU, modifiers: [.control, .shift]))
        #expect(commands[0].shortcutKey.name == "shortcuts.translateUnderCursor")
        #expect(commands[1].title == "Translate File…" && commands[1].route == "translate/file" && commands[1].defaultShortcut == nil)
    }

    @Test func withoutScreenRecordingTheModeExplainsAndDoesNotStart() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let coordinator = coordinator(settings.store)
        let explained = Counter()
        coordinator.screenCapture = { _ in throw TranslationFailure.unavailable("not used") }
        coordinator.cursorPermissions = CursorPermissions(
            hasScreenRecording: { false },
            hasAccessibility: { false },
            explainMissingScreenRecording: { explained.count += 1 }
        )
        coordinator.toggleTranslateUnderCursor()
        #expect(!coordinator.isTranslatingUnderCursor && explained.count == 1)
        #expect(coordinator.commands[0].title == "Translate Under Cursor")
        coordinator.stopTranslatingUnderCursor()
        #expect(!coordinator.isTranslatingUnderCursor)
    }

    @Test func cursorTranslationsUseTheProviderAndGlossarySettingsChoose() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        settings.store[TranslationKeys.targetLanguage] = "ja"
        let fake = FakeProvider(id: .apple)
        let coordinator = coordinator(settings.store, provider: fake)
        let project = coordinator.glossaries.addProject(named: "UI")
        let pair = try #require(coordinator.glossaries.addPair(source: "en", target: "ja", to: project.id))
        coordinator.glossaries.importRows(
            [GlossaryCSV.Row(term: GlossaryTerm(source: "panel", target: "パネル"))],
            into: pair.id,
            of: project.id
        )
        coordinator.glossaries.activeProjectID = project.id

        let result = try await coordinator.translateUnderCursor("Open the capture panel to see every screenshot")
        #expect(result.translation == "[ja] Open the capture panel to see every screenshot")
        #expect(result.sourceLanguage == "en" && result.targetLanguage == "ja" && result.providerName == "Apple Translation")
        #expect(!result.isSameLanguage && result.caption.hasSuffix(" · Apple Translation"))
        #expect(fake.requests.first?.glossary.usableTerms.map(\.target) == ["パネル"])
        #expect(coordinator.usage.usage(for: .apple).requests == 1)
        #expect(coordinator.cursorContext == "apple|ja|\(project.id.uuidString)|")

        settings.store[TranslationKeys.targetLanguage] = "en"
        let same = try await coordinator.translateUnderCursor("This sentence is already written in English.")
        #expect(same.isSameLanguage && fake.requests.count == 1)
    }
}
