import Foundation
@testable import OrielTranslation
import Testing
import Translation

/// Apple Translation through a fake backend: the availability states and how they reach the UI.
struct AppleTranslationProviderTests {
    private let english = Locale.Language(identifier: "en")
    private let japanese = Locale.Language(identifier: "ja")

    @Test(arguments: [
        (AppleLanguageStatus.installed, ProviderAvailability.available),
        (.supported, .packNotInstalled(source: "en", target: "ja")),
        (.unsupported, .unsupportedLanguagePair(source: "en", target: "ja")),
    ])
    func mapsPackStatusToAvailability(_ status: AppleLanguageStatus, _ expected: ProviderAvailability) async {
        let backend = FakeAppleBackend(status: status)
        let provider = AppleTranslationProvider(backend: backend)
        #expect(await provider.availability(source: english, target: japanese) == expected)
        #expect(backend.log == ["status en→ja"])
    }

    @Test func needsASourceLanguageButNotForTextAlreadyInTheTarget() async {
        let backend = FakeAppleBackend(status: .unsupported)
        let provider = AppleTranslationProvider(backend: backend)
        #expect(await provider.availability(source: nil, target: japanese) == .sourceLanguageUnknown)
        #expect(await provider.availability(source: Locale.Language(identifier: "en-GB"), target: english) == .available)
        #expect(backend.log.isEmpty)
    }

    @Test(arguments: [
        (ProviderAvailability.available, nil as ProviderAvailability.Action?, "checkmark.circle"),
        (.packNotInstalled(source: "en", target: "ja"), .downloadLanguagePack, "arrow.down.circle"),
        (.unsupportedLanguagePair(source: "en", target: "ja"), .chooseAnotherProvider, "nosign"),
        (.sourceLanguageUnknown, .chooseAnotherProvider, "questionmark.circle"),
        (.missingAPIKey, .addAPIKey, "key"),
        (.offline, .chooseAnotherProvider, "wifi.slash"),
        (.capReached, .openSettings, "gauge.with.dots.needle.100percent"),
    ])
    func availabilityStatesMapToTheUI(_ availability: ProviderAvailability, _ action: ProviderAvailability.Action?, _ symbol: String) {
        #expect(availability.action == action)
        #expect(availability.symbol == symbol)
        #expect(!availability.message.isEmpty)
        #expect(availability.isAvailable == (availability == .available))
        #expect((availability.failure == nil) == availability.isAvailable)
    }

    @Test func namesTheLanguagesOfAMissingPack() {
        let message = ProviderAvailability.packNotInstalled(source: "en", target: "ja").message
        #expect(message.contains(LanguageCatalog.name(of: "en")) && message.contains(LanguageCatalog.name(of: "ja")))
    }

    @Test func detectsTheSourceLanguageAndTranslatesWithTheInstalledPack() async throws {
        let backend = FakeAppleBackend(status: .installed)
        let request = TestSupport.request(["Good morning, how are you today?", "The weather is lovely."], source: nil, target: "ja")
        let result = try await TestSupport.collect(AppleTranslationProvider(backend: backend).translate(request))
        #expect(backend.log == ["status en→ja", "translate en→ja ×2"])
        #expect(result.translations == [1: "[ja] Good morning, how are you today?", 2: "[ja] The weather is lovely."])
        #expect(result.usage?.characters == request.characterCount)
    }

    @Test func failsWithPackNotInstalledInsteadOfDownloading() async {
        let backend = FakeAppleBackend(status: .supported)
        let failure = await TestSupport.failure(of: AppleTranslationProvider(backend: backend).translate(TestSupport.request(
            ["Hello"],
            target: "ja"
        )))
        #expect(failure == .packNotInstalled(source: "en", target: "ja"))
        #expect(!backend.log.contains { $0.hasPrefix("translate") })
    }

    @Test func returnsTextAlreadyInTheTargetLanguageUnchanged() async throws {
        let backend = FakeAppleBackend(status: .installed)
        let result = try await TestSupport.collect(AppleTranslationProvider(backend: backend).translate(TestSupport.request(
            ["Hello"],
            target: "en"
        )))
        #expect(result.translations == [1: "Hello"])
        #expect(backend.log.isEmpty)
    }

    @Test func failsWhenNoLanguageCanBeDetected() async {
        let backend = FakeAppleBackend(status: .installed)
        let failure = await TestSupport.failure(of: AppleTranslationProvider(backend: backend).translate(TestSupport.request(
            ["12:45"],
            source: nil
        )))
        #expect(failure == .sourceLanguageUnknown)
    }

    @Test func mapsTranslationFrameworkErrors() {
        let failure = { (error: any Error) in SystemTranslationBackend.failure(for: error, source: english, target: japanese) }
        #expect(failure(TranslationError.notInstalled) == .packNotInstalled(source: "en", target: "ja"))
        #expect(failure(TranslationError.unsupportedLanguagePairing) == .unsupportedLanguagePair(source: "en", target: "ja"))
        #expect(failure(TranslationError.unableToIdentifyLanguage) == .sourceLanguageUnknown)
        #expect(failure(TranslationError.nothingToTranslate) == .noText)
        #expect(failure(CancellationError()) == .cancelled)
    }
}
