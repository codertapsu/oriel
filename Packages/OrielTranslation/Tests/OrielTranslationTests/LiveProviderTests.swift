import Foundation
@testable import OrielTranslation
import Testing

/// Contract tests against a real local server (PLAN §14.2), only with `ORIEL_LIVE_PROVIDER_TESTS=1`. They talk to the
/// Ollama on this Mac and nothing else: `ORIEL_OLLAMA_URL` (default http://localhost:11434/v1) and
/// `ORIEL_OLLAMA_MODEL` (default qwen2.5:7b, the model installed on the dev Mac).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ORIEL_LIVE_PROVIDER_TESTS"] == "1", "set ORIEL_LIVE_PROVIDER_TESTS=1"))
struct LiveProviderTests {
    private var provider: OpenAICompatibleProvider {
        let environment = ProcessInfo.processInfo.environment
        let config = ProviderConfig(
            id: "ollama",
            kind: .openAICompatible,
            displayName: "Ollama",
            baseURL: environment["ORIEL_OLLAMA_URL"] ?? "http://localhost:11434/v1",
            model: environment["ORIEL_OLLAMA_MODEL"] ?? "qwen2.5:7b",
            temperature: 0,
            timeoutSeconds: 180
        )
        return OpenAICompatibleProvider(config: config, apiKey: nil, http: .makeDefault())
    }

    @Test func ollamaListsTheConfiguredModel() async throws {
        let summary = try await provider.testConnection()
        #expect(summary.contains("is available"), "\(summary)")
    }

    @Test func ollamaTranslatesSegmentsWithTheJSONContract() async throws {
        let request = TestSupport.request(["Hello world", "Good morning", "Open the settings window"], source: "en", target: "fr")
        let result = try await TestSupport.collect(provider.translate(request))
        #expect(Set(result.translations.keys) == [1, 2, 3])
        #expect(result.translations.values.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(result.translations[1]?.localizedCaseInsensitiveContains("monde") == true)
        #expect((result.usage?.outputTokens ?? 0) > 0)
    }
}
