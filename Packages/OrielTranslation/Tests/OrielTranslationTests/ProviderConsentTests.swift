import CoreGraphics
import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

/// Consent before text leaves the Mac (App Review Guidelines 5.1.2(i), PLAN §19): needed for providers off this Mac
/// only, kept per provider, taken back in Settings, and never asked for by the headless path.
@MainActor
struct ProviderConsentTests {
    @Test func onlyProvidersOffThisMacNeedIt() {
        #expect(!ProviderConsent.isNeeded(for: ProviderConfig(id: "apple", kind: .apple)))
        #expect(!ProviderConsent.isNeeded(for: ProviderConfig(id: "fm", kind: .foundationModels)))
        #expect(!ProviderConsent.isNeeded(for: ProviderConfig(id: "ollama", kind: .openAICompatible, baseURL: "http://localhost:11434/v1")))
        #expect(ProviderConsent.isNeeded(for: ProviderConfig(id: "lan", kind: .openAICompatible, baseURL: "http://192.168.1.5:8080/v1")))
        #expect(ProviderConsent.isNeeded(for: ProviderConfig(id: "deepl", kind: .deepl)))
        #expect(ProviderConsent.isNeeded(for: ProviderConfig(id: "anthropic", kind: .anthropic)))
    }

    @Test func itIsKeptPerProviderAndCanBeTakenBack() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let consent = ProviderConsent(settings: settings.store)
        let deepL = ProviderConfig(id: "deepl", kind: .deepl)
        let google = ProviderConfig(id: "google", kind: .google)
        #expect(!consent.isGranted(deepL))
        consent.set(true, for: deepL)
        #expect(consent.isGranted(deepL) && !consent.isGranted(google))
        consent.set(false, for: deepL)
        #expect(!consent.isGranted(deepL))
    }

    @Test func theHeadlessPathFailsInsteadOfAsking() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        settings.store[TranslationKeys.providers] = ProviderConfig.builtIns + [ProviderConfig(id: "deepl", kind: .deepl)]
        ProAccess.shared.setUnlocked(true)
        let coordinator = TranslationCoordinator(
            settings: settings.store,
            secrets: InMemorySecrets(),
            textRecognizer: FakeTextRecognizer([
                OCRBlock(id: 1, text: "Hello", boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, language: "en"),
            ]),
            http: HTTPClient(session: StubURLProtocol.session),
            historyDirectory: FileManager.default.temporaryDirectory.appending(path: "oriel-consent-\(UUID().uuidString)"),
            foundationModelsGate: { .open }
        )
        await #expect(throws: TranslationFailure.notAllowed("DeepL")) {
            try await coordinator.translateHeadless(image: TestSupport.image(), target: "ja", providerID: "deepl")
        }
    }
}
