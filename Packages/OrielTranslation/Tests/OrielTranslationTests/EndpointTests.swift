import Foundation
@testable import OrielTranslation
import Testing

struct EndpointTests {
    @Test(arguments: [
        ("http://localhost:11434/v1", "chat/completions", "v1", "http://localhost:11434/v1/chat/completions"),
        ("http://localhost:11434", "chat/completions", "v1", "http://localhost:11434/v1/chat/completions"),
        ("http://localhost:11434/v1/", "chat/completions", "v1", "http://localhost:11434/v1/chat/completions"),
        ("https://api.openai.com/v1/chat/completions", "chat/completions", "v1", "https://api.openai.com/v1/chat/completions"),
        ("https://proxy.internal/openai/v1", "models", "v1", "https://proxy.internal/openai/v1/models"),
        ("https://api.anthropic.com", "messages", "v1", "https://api.anthropic.com/v1/messages"),
        ("https://api.deepl.com/v2", "translate", "v2", "https://api.deepl.com/v2/translate"),
        ("https://translation.googleapis.com", "", "language/translate/v2", "https://translation.googleapis.com/language/translate/v2"),
    ])
    func joinsWhateverTheUserTyped(base: String, path: String, prefix: String, expected: String) {
        #expect(Endpoint.url(base, path: path, versionPrefix: prefix)?.absoluteString == expected)
    }

    @Test func rejectsWhatIsNotAnHTTPURL() {
        #expect(Endpoint.url("", path: "models") == nil)
        #expect(Endpoint.url("localhost:11434", path: "models") == nil)
        #expect(Endpoint.url("ftp://example.com", path: "models") == nil)
    }

    @Test func recognizesServersOnThisMac() {
        #expect(Endpoint.isLocal("http://localhost:11434/v1") && Endpoint.isLocal("http://127.0.0.1:1234/v1"))
        #expect(!Endpoint.isLocal("http://ollama.internal:11434/v1") && !Endpoint.isLocal("https://api.openai.com/v1"))
        #expect(TranslationCoordinator.worksOffline(ProviderConfig(id: .apple, kind: .apple)))
        #expect(!TranslationCoordinator.worksOffline(ProviderConfig(id: "deepl", kind: .deepl)))
    }

    /// PLAN §7.7.7, §11: a model running on an Intel Mac gets a warning; a server elsewhere, or Apple silicon, none.
    @Test func modelsRunningOnAnIntelMacAreFlaggedAsSlow() {
        let local = ProviderConfig(id: "ollama", kind: .openAICompatible, baseURL: "http://localhost:11434/v1")
        let remote = ProviderConfig(id: "ollama", kind: .openAICompatible, baseURL: "http://ollama.internal:11434/v1")
        #expect(TranslationSettingsModel.localModelWarning(for: local, isAppleSilicon: false)?.contains("Intel") == true)
        #expect(TranslationSettingsModel.localModelWarning(for: local, isAppleSilicon: true) == nil)
        #expect(TranslationSettingsModel.localModelWarning(for: remote, isAppleSilicon: false) == nil)
        #expect(TranslationSettingsModel.localModelWarning(for: ProviderConfig(id: .apple, kind: .apple), isAppleSilicon: false) == nil)
    }
}
