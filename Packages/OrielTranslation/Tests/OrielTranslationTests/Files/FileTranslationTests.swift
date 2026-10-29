import CoreGraphics
import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

/// Translating whole files through the coordinator, without its window: chunks, progress, a failure partway and
/// Resume, files already in the target language, images, subtitles, glossaries and exports.
@MainActor
struct FileTranslationTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "oriel-file-translation-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func cleanUp(_ settings: TemporarySettings) {
        settings.remove()
        try? FileManager.default.removeItem(at: folder)
    }

    private func coordinator(
        _ settings: SettingsStore,
        provider: any TranslationProvider,
        recognizer: FakeTextRecognizer? = nil
    ) -> TranslationCoordinator {
        settings[TranslationKeys.targetLanguage] = "ja"
        return TranslationCoordinator(
            settings: settings,
            secrets: InMemorySecrets(),
            textRecognizer: recognizer ?? FakeTextRecognizer([]),
            http: HTTPClient(session: StubURLProtocol.session),
            historyDirectory: folder.appending(path: "history"),
            providerOverride: { $0.id == .apple ? provider : nil },
            foundationModelsGate: { .open }
        )
    }

    private func paragraphs(_ count: Int) throws -> URL {
        let text = (1 ... count).map { "Paragraph number \($0) explains how a long document is translated." }.joined(separator: "\n\n")
        let url = folder.appending(path: "guide.txt")
        try Data(text.utf8).write(to: url)
        return url
    }

    @Test func translatesAFileInChunksWithinTheProvidersLimits() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let provider = FlakyProvider()
        let coordinator = coordinator(settings.store, provider: provider)
        try coordinator.startFileTranslation(paragraphs(90))
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        #expect(model.phase == .finished && model.translatedCount == 90 && model.translatableCount == 90)
        // Apple Translation's limits: 40 segments a request.
        #expect(provider.requests.map(\.segments.count) == [40, 40, 10])
        #expect(model.sourceLanguage.map(LanguageCatalog.code(for:)) == "en")
        #expect(model.statusText == "Translated 90 paragraphs with Apple Translation")
        #expect(coordinator.usage.usage(for: .apple).requests == 3)
        let text = try #require(coordinator.exportData(of: model, as: .text).flatMap { String(bytes: $0, encoding: .utf8) })
        #expect(text.hasPrefix("[ja] Paragraph number 1 explains") && text
            .hasSuffix("[ja] Paragraph number 90 explains how a long document is translated.\n"))
    }

    @Test func aFailurePartwayKeepsWhatWasTranslatedAndResumeFinishesIt() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let provider = FlakyProvider()
        provider.fail(onRequest: 2)
        let coordinator = coordinator(settings.store, provider: provider)
        try coordinator.startFileTranslation(paragraphs(90))
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        #expect(model.phase == .failed(TranslationFailure.rateLimited(retryAfter: 30).localizedDescription))
        #expect(model.translatedCount == 40 && model.statusText.contains("40 of 90 paragraphs translated"))

        provider.fail(onRequest: nil)
        coordinator.resumeFileTranslation()
        await coordinator.fileTask?.value
        #expect(model.phase == .finished && model.translatedCount == 90)
        // Only what was missing went out again.
        #expect(provider.requests.map(\.segments.count) == [40, 40, 40, 10])
    }

    @Test func stoppingWhileAPageIsReadKeepsTheRestToReadOnResume() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let recognizer = GatedTextRecognizer([
            OCRBlock(id: 1, text: "Words on the scanned page", boundingBox: CGRect(x: 10, y: 10, width: 300, height: 30), confidence: 0.9),
        ])
        let provider = FlakyProvider()
        let coordinator = TranslationCoordinator(
            settings: settings.store, secrets: InMemorySecrets(), textRecognizer: recognizer,
            http: HTTPClient(session: StubURLProtocol.session), historyDirectory: folder.appending(path: "history"),
            providerOverride: { $0.id == .apple ? provider : nil }, foundationModelsGate: { .open }
        )
        settings.store[TranslationKeys.targetLanguage] = "ja"
        let url = folder.appending(path: "mixed.pdf")
        try PDFFixture.write(to: url)
        coordinator.startFileTranslation(url)
        await recognizer.waitForCall()
        // Page 2 is being read; let page 1's translation, which runs alongside, come in first.
        let model = try #require(coordinator.fileModel)
        for _ in 0 ..< 10000 where model.translatedCount < 2 {
            await Task.yield()
        }
        let job = coordinator.fileTask
        coordinator.stopFileTranslation()
        recognizer.release()
        await job?.value
        #expect(model.phase == .cancelled && !model.isComplete && model.segments.allSatisfy { $0.page == 1 })
        #expect(model.translatedCount == 2)

        recognizer.release()
        coordinator.resumeFileTranslation()
        await coordinator.fileTask?.value
        #expect(model.phase == .finished && model.isComplete && model.translatedCount == 3)
        #expect(model.translations[3] == "[ja] Words on the scanned page")
        // Page 1 was not sent again.
        #expect(provider.requests.map(\.segments.count) == [2, 1])
    }

    @Test func changingTheTargetTranslatesEverythingAgain() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let provider = FlakyProvider()
        let coordinator = coordinator(settings.store, provider: provider)
        try coordinator.startFileTranslation(paragraphs(3))
        await coordinator.fileTask?.value
        coordinator.fileActions().selectTarget("fr")
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        #expect(model.targetCode == "fr" && model.translations.values.allSatisfy { $0.hasPrefix("[fr] ") })
        #expect(provider.requests.count == 2 && settings.store[TranslationKeys.targetLanguage] == "fr")
    }

    @Test func textAlreadyInTheTargetLanguageIsNotSent() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let provider = FlakyProvider()
        let coordinator = coordinator(settings.store, provider: provider)
        settings.store[TranslationKeys.targetLanguage] = "en"
        coordinator.fileTranslationModel().targetLanguage = Locale.Language(identifier: "en")
        try coordinator.startFileTranslation(paragraphs(5))
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        #expect(provider.requests.isEmpty && model.note == "Already in \(LanguageCatalog.name(of: "en"))" && model.phase == .finished)
    }

    @Test func filesOrielCannotReadAreRefusedWithAReason() throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let coordinator = coordinator(settings.store, provider: FlakyProvider())
        coordinator.startFileTranslation(folder.appending(path: "archive.zip"))
        let model = try #require(coordinator.fileModel)
        guard case let .failed(message) = model.phase else {
            Issue.record("a zip file should be refused")
            return
        }
        #expect(model.kind == nil && message.contains(".zip"))
    }

    @Test func imagesGetTheirTranslationDrawnOverThem() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let recognizer = FakeTextRecognizer([
            OCRBlock(id: 1, text: "Good morning", boundingBox: CGRect(x: 20, y: 20, width: 260, height: 40), confidence: 0.9),
        ])
        let coordinator = coordinator(settings.store, provider: FlakyProvider(), recognizer: recognizer)
        let url = folder.appending(path: "sign.png")
        try #require(ImageEncoder.data(TestSupport.image(width: 300, height: 100, red: 0.1, green: 0.2, blue: 0.6), type: .png))
            .write(to: url)
        coordinator.startFileTranslation(url)
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        let annotated = try #require(model.annotatedImage)
        #expect(annotated.width == 300 && annotated.height == 100 && model.translations == [1: "[ja] Good morning"])
        #expect(coordinator.exportData(of: model, as: .image)?.starts(with: [0x89, 0x50, 0x4E, 0x47]) == true)
    }

    @Test func subtitlesComeBackWithTheirTiming() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let coordinator = coordinator(settings.store, provider: FlakyProvider())
        let url = folder.appending(path: "film.srt")
        try Data("1\n00:00:01,000 --> 00:00:02,500\nHello there, how are you today?\n\n2\n00:00:03,000 --> 00:00:04,000\nFine, thanks.\n"
            .utf8)
            .write(to: url)
        coordinator.startFileTranslation(url)
        await coordinator.fileTask?.value
        let model = try #require(coordinator.fileModel)
        let srt = try #require(coordinator.exportData(of: model, as: .srt).flatMap { String(bytes: $0, encoding: .utf8) })
        let first = "1\n00:00:01,000 --> 00:00:02,500\n[ja] Hello there, how are you today?\n\n"
        #expect(srt == first + "2\n00:00:03,000 --> 00:00:04,000\n[ja] Fine, thanks.\n\n")
    }

    @Test func theActiveGlossaryGoesWithEveryChunk() async throws {
        let settings = try TemporarySettings()
        defer { cleanUp(settings) }
        let provider = FlakyProvider()
        let coordinator = coordinator(settings.store, provider: provider)
        let project = coordinator.glossaries.addProject(named: "Docs")
        let pair = try #require(coordinator.glossaries.addPair(source: "en", target: "ja", to: project.id))
        coordinator.glossaries.importRows(
            [GlossaryCSV.Row(term: GlossaryTerm(source: "document", target: "ドキュメント"))],
            into: pair.id,
            of: project.id
        )
        coordinator.glossaries.activeProjectID = project.id
        try coordinator.startFileTranslation(paragraphs(45))
        await coordinator.fileTask?.value
        #expect(provider.requests.count == 2)
        #expect(provider.requests.allSatisfy { $0.glossary.projectID == project.id && $0.glossary.usableTerms.map(\.target) == ["ドキュメント"] })
    }
}
