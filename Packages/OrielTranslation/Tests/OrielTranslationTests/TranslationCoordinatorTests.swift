import CoreGraphics
import Foundation
import ImageIO
import OrielCore
@testable import OrielTranslation
import Testing

/// The coordinator's headless flow and its pieces that need no window. The interactive overlay is not tested here,
/// because tests must not show windows on the developer's Mac.
@MainActor
struct TranslationCoordinatorTests {
    private let blocks = [
        OCRBlock(id: 1, text: "Hello world", boundingBox: CGRect(x: 10, y: 20, width: 200, height: 30), confidence: 0.9, language: "en"),
        OCRBlock(
            id: 2,
            text: "Good morning everyone",
            boundingBox: CGRect(x: 10, y: 80, width: 260, height: 30),
            confidence: 0.8,
            language: "en"
        ),
    ]

    private func coordinator(
        _ settings: SettingsStore,
        recognizer: FakeTextRecognizer? = nil,
        http: HTTPClient = HTTPClient(session: StubURLProtocol.session),
        override: ProviderRegistry.ProviderOverride? = nil
    ) -> TranslationCoordinator {
        TranslationCoordinator(
            settings: settings,
            secrets: InMemorySecrets(),
            textRecognizer: recognizer ?? FakeTextRecognizer(blocks),
            http: http,
            historyDirectory: FileManager.default.temporaryDirectory.appending(path: "oriel-history-\(UUID().uuidString)"),
            providerOverride: override,
            foundationModelsGate: { .open }
        )
    }

    @Test func headlessTranslationReturnsEveryBlockWithItsBoxAndTranslation() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let fake = FakeProvider(id: .apple)
        let coordinator = coordinator(settings.store) { $0.id == .apple ? fake : nil }
        let outcome = try await coordinator.translateHeadless(image: TestSupport.image(), target: "ja", providerID: nil)

        #expect(outcome.providerID == "apple" && outcome.sourceLanguage == "en" && outcome.targetLanguage == "ja")
        #expect(outcome.blocks.map(\.translation) == ["[ja] Hello world", "[ja] Good morning everyone"])
        #expect(outcome.blocks.first?.box == TranslationOutcome.Box(x: 10, y: 20, width: 200, height: 30))
        #expect(fake.requests.first?.source == Locale.Language(identifier: "en"))
        #expect(coordinator.usage.usage(for: .apple).characters == 32)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try #require(String(data: encoder.encode(outcome), encoding: .utf8))
        let firstBlock = #"{"blocks":[{"box":{"height":30,"width":200,"x":10,"y":20},"#
            + #""id":1,"source":"Hello world","translation":"[ja] Hello world"}"#
        #expect(json.hasPrefix(firstBlock))
        #expect(json.hasSuffix(#""providerID":"apple","sourceLanguage":"en","targetLanguage":"ja"}"#))
    }

    @Test func headlessTranslationUsesTheNamedProviderOverTheNetwork() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let answer = #"[{"id":1,"translation":"Bonjour le monde"},{"id":2,"translation":"Bonjour à tous"}]"#
        let server = StubServer { _ in .events(TestSupport.openAIStream(answer)) }
        settings.store[TranslationKeys.providers] = ProviderConfig.builtIns + [
            ProviderConfig(id: "ollama", kind: .openAICompatible, baseURL: "\(server.baseURL)/v1", model: "qwen2.5:7b"),
        ]
        let coordinator = coordinator(settings.store, http: server.http)
        let outcome = try await coordinator.translateHeadless(image: TestSupport.image(), target: "fr", providerID: "ollama")
        #expect(outcome.providerID == "ollama")
        #expect(outcome.blocks.map(\.translation) == ["Bonjour le monde", "Bonjour à tous"])
        #expect(server.requests.count == 1)
        #expect(coordinator.usage.usage(for: "ollama").tokens == 59)
    }

    @Test func headlessTranslationReportsWhatStandsInTheWay() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let apple = AppleTranslationProvider(backend: FakeAppleBackend(status: .supported))
        let coordinator = coordinator(settings.store) { $0.id == .apple ? apple : nil }
        await #expect(throws: TranslationFailure.packNotInstalled(source: "en", target: "ja")) {
            try await coordinator.translateHeadless(image: TestSupport.image(), target: "ja", providerID: "apple")
        }
        await #expect(throws: TranslationFailure.unknownProvider("nope")) {
            try await coordinator.translateHeadless(image: TestSupport.image(), target: "ja", providerID: "nope")
        }
        settings.store[TranslationKeys.providers] = ProviderConfig.builtIns + [ProviderConfig(id: "deepl", kind: .deepl, monthlyCap: 10)]
        coordinator.usage.record(TranslationUsage(characters: 25), for: "deepl")
        await #expect(throws: TranslationFailure.capReached) {
            try await coordinator.translateHeadless(image: TestSupport.image(), target: "ja", providerID: "deepl")
        }
    }

    @Test func textAlreadyInTheTargetLanguageIsNotSentAnywhere() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let fake = FakeProvider(id: .apple)
        let coordinator = coordinator(settings.store) { _ in fake }
        let outcome = try await coordinator.translateHeadless(image: TestSupport.image(), target: "en-GB", providerID: nil)
        #expect(outcome.blocks.map(\.translation) == ["Hello world", "Good morning everyone"])
        #expect(fake.requests.isEmpty)
    }

    @Test func aFixedSourceLanguageIsTheOCRHintAndTheRequestsSource() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        settings.store[TranslationKeys.sourceLanguage] = "de"
        settings.store[TranslationKeys.targetLanguage] = "fr"
        let recognizer = FakeTextRecognizer(blocks)
        let fake = FakeProvider(id: .apple)
        let coordinator = coordinator(settings.store, recognizer: recognizer) { _ in fake }
        let outcome = try await coordinator.translateHeadless(image: TestSupport.image(), target: nil, providerID: nil)
        #expect(recognizer.receivedHints == [["de"]])
        #expect(fake.requests.first?.source == Locale.Language(identifier: "de"))
        #expect(outcome.sourceLanguage == "de" && outcome.targetLanguage == "fr")
    }

    @Test func settingsPaneAndBootstrapNeedNoWindow() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let coordinator = coordinator(settings.store)
        _ = coordinator.settingsPane
        coordinator.applyBootstrap(
            [BootstrapProvider(id: "lmstudio", kind: "openai-compatible", baseURL: "http://localhost:1234/v1")],
            defaultProvider: nil
        )
        #expect(coordinator.registry.config(for: "lmstudio")?.displayName == "LM Studio")
    }

    @Test func exportsTextMarkdownAndTheAnnotatedImage() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let coordinator = coordinator(settings.store)
        let capture = try CaptureResult(image: TestSupport.image(width: 600, height: 240), kind: .area, rect: .zero, scale: 2)
        let model = TranslationSessionModel(capture: capture, providerID: .apple, targetLanguage: Locale.Language(identifier: "fr"))
        model.sourceLanguage = Locale.Language(identifier: "en")
        model.setBlocks(blocks)
        model.apply(TranslatedSegment(id: 1, text: "Bonjour le monde"))
        model.apply(TranslatedSegment(id: 2, text: "Bonjour à tous"))

        let text = try #require(coordinator.exportData(for: model, as: .text).flatMap { String(data: $0, encoding: .utf8) })
        #expect(text == "Bonjour le monde\n\nBonjour à tous\n")
        let markdown = try #require(coordinator.exportData(for: model, as: .markdown).flatMap { String(data: $0, encoding: .utf8) })
        #expect(markdown.hasPrefix("# Translation\n") && markdown.contains("> Hello world\n\nBonjour le monde"))
        let png = try #require(coordinator.exportData(for: model, as: .annotatedImage))
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 600 && image.height == 240)
    }

    @Test func sessionModelKeepsVisionOnlyTextAndDropsUnknownIDs() throws {
        let capture = try CaptureResult(image: TestSupport.image(), kind: .area, rect: .zero, scale: 1)
        let model = TranslationSessionModel(capture: capture, providerID: .apple, targetLanguage: Locale.Language(identifier: "fr"))
        model.setBlocks(blocks)
        model.apply(TranslatedSegment(id: 9, text: "ignored"))
        model.apply(TranslatedSegment(id: 1001, text: "Vertical", source: "縦"))
        #expect(model.blocks.count == 2)
        model.usesImageInput = true
        model.apply(TranslatedSegment(id: 1001, text: "Vertical", source: "縦"))
        #expect(model.blocks.map(\.id) == [1, 2, 1001] && model.blocks.last?.box == nil)
        #expect(model.segments.map(\.id) == [1, 2])
        model.clearTranslations()
        #expect(model.blocks.map(\.id) == [1, 2] && model.translatedCount == 0)
    }
}
