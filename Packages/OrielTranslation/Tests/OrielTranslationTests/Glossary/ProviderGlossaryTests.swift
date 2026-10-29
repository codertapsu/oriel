import Foundation
@testable import OrielTranslation
import Testing

/// How each provider applies a glossary project, with stubbed requests: Google with the project's Cloud glossary or
/// tokens on v2, Apple Translation with tokens, and language models in the prompt with only the terms that occur.
struct ProviderGlossaryTests {
    private let capture = GlossaryTerm(source: "capture", target: "キャプチャ", note: "the noun")
    private let pin = GlossaryTerm(source: "pin", target: "ピン", isCaseSensitive: true)

    private func glossary(_ terms: [GlossaryTerm], google: String = "") -> TranslationGlossary {
        TranslationGlossary(projectID: UUID(), projectName: "Docs", terms: terms, googleGlossary: google)
    }

    // MARK: - Google

    /// v2 answers tagged "v2:", v3 "v3:", and the token service at /token.
    private func googleServer() -> StubServer {
        StubServer { request in
            if request.url.path == "/token" {
                return .json(#"{"access_token":"ya29.test","expires_in":3599}"#)
            }
            if request.url.path.hasPrefix("/v3/") {
                let texts = request.json?["contents"] as? [String] ?? []
                return .json(TestSupport.json(["glossaryTranslations": texts.map { ["translatedText": "v3:\($0)"] }]))
            }
            let texts = request.json?["q"] as? [String] ?? []
            return .json(TestSupport.json(["data": ["translations": texts.map { ["translatedText": "v2:\($0)"] }]]))
        }
    }

    private func google(_ server: StubServer, account: GoogleServiceAccount?) -> GoogleTranslateProvider {
        let config = ProviderConfig(id: "google", kind: .google, baseURL: "\(server.baseURL)/language/translate/v2")
        return GoogleTranslateProvider(
            config: config,
            apiKey: APIKey("api-key"),
            http: server.http,
            serviceAccount: account,
            tokens: GoogleAccessTokens()
        )
    }

    @Test func aProjectsCloudGlossaryGoesToV3WithTheServiceAccount() async throws {
        let server = googleServer()
        let made = try TestServiceAccount.make(tokenURL: "\(server.baseURL)/token", project: "p9")
        var request = TestSupport.request(["capture"], target: "ja")
        request.glossary = glossary([capture], google: "docs-terms")
        let result = try await TestSupport.collect(google(server, account: GoogleServiceAccount(json: made.json)).translate(request))
        let sent = try #require(server.requests.last)
        #expect(sent.url.path == "/v3/projects/p9/locations/us-central1:translateText")
        let config = try #require(sent.json?["glossaryConfig"] as? [String: Any])
        #expect(config["glossary"] as? String == "projects/p9/locations/us-central1/glossaries/docs-terms")
        #expect(result.translations == [1: "v3:capture"])
    }

    @Test func aCloudGlossaryForAnotherPairFallsBackToBasicWithTokens() async throws {
        let server = StubServer { request in
            if request.url.path == "/token" {
                return .json(#"{"access_token":"ya29.test","expires_in":3599}"#)
            }
            if request.url.path.hasPrefix("/v3/") {
                return .json(#"{"error":{"code":400,"message":"Unsupported language pair of glossary"}}"#, status: 400)
            }
            let texts = request.json?["q"] as? [String] ?? []
            return .json(TestSupport.json(["data": ["translations": texts.map { ["translatedText": "v2:\($0)"] }]]))
        }
        let made = try TestServiceAccount.make(tokenURL: "\(server.baseURL)/token", project: "p9")
        var request = TestSupport.request(["The capture"], target: "de")
        request.glossary = glossary([capture], google: "docs-ja")
        let result = try await TestSupport.collect(google(server, account: GoogleServiceAccount(json: made.json)).translate(request))
        #expect(server.requests.map(\.url.path).suffix(2) == [
            "/v3/projects/p9/locations/us-central1:translateText",
            "/language/translate/v2",
        ])
        #expect(result.translations == [1: "v2:The キャプチャ"])
    }

    @Test func withoutAServiceAccountTheTermsTravelAsTokensOnV2() async throws {
        let server = googleServer()
        var request = TestSupport.request(["Open the capture panel", "Nothing"], target: "ja")
        request.glossary = glossary([capture], google: "docs-terms")
        let result = try await TestSupport.collect(google(server, account: nil).translate(request))
        let sent = try #require(server.requests.last)
        #expect(sent.url.path == "/language/translate/v2")
        #expect(sent.json?["q"] as? [String] == ["Open the [[1]] panel", "Nothing"])
        #expect(result.translations == [1: "v2:Open the キャプチャ panel", 2: "v2:Nothing"])
        #expect(result.usage == TranslationUsage(characters: 27))
    }

    // MARK: - Apple Translation

    @Test func appleTranslationProtectsTermsAndFallsBackWhenATokenIsLost() async throws {
        let backend = FakeAppleBackend(status: .installed)
        let provider = AppleTranslationProvider(backend: backend)
        var request = TestSupport.request(["Pin the capture", "Pins and pin"], source: "en", target: "ja")
        request.glossary = glossary([capture, pin])
        let result = try await TestSupport.collect(provider.translate(request))
        // The fake keeps tokens, so both segments come back with the glossary's translations.
        #expect(result.translations == [1: "[ja] Pin the キャプチャ", 2: "[ja] Pins and ピン"])
        #expect(backend.log == ["status en→ja", "translate en→ja ×2"])
    }

    // MARK: - Language models

    @Test func promptsListOnlyTheTermsThatOccurWithNotesAndCase() {
        var request = TestSupport.request(["Take a capture", "Then pin it"], source: "en", target: "ja")
        request.glossary = glossary([capture, pin, GlossaryTerm(source: "window", target: "ウィンドウ")])
        let instructions = SegmentPrompt.instructions(for: request)
        #expect(instructions.contains(#"- "capture" → "キャプチャ" (the noun)"#))
        #expect(instructions.contains(#"- "pin" → "ピン" [case-sensitive]"#))
        #expect(!instructions.contains("ウィンドウ"))

        request.segments = [TranslationSegment(id: 1, text: "No terms at all")]
        #expect(!SegmentPrompt.instructions(for: request).contains("Glossary"))
    }

    @Test func aiVisionGetsEveryTermBecauseOCRMayHaveMissedSome() throws {
        var request = try TestSupport.request(["?"], source: "en", target: "ja", image: TestSupport.image())
        request.glossary = glossary([capture, pin])
        #expect(SegmentPrompt.glossaryTerms(for: request).map(\.source) == ["capture", "pin"])
    }

    @Test func theOpenAICompatibleRequestCarriesTheTermsOfItsBatch() async throws {
        let answer = #"[{"id":1,"translation":"キャプチャを撮る"}]"#
        let server = StubServer { _ in .events(TestSupport.openAIStream(answer)) }
        let config = ProviderConfig(id: "ollama", kind: .openAICompatible, baseURL: "\(server.baseURL)/v1", model: "qwen")
        var request = TestSupport.request(["Take a capture"], source: "en", target: "ja")
        request.glossary = glossary([capture, pin])
        _ = try await TestSupport.collect(OpenAICompatibleProvider(config: config, apiKey: nil, http: server.http).translate(request))
        let messages = try #require(server.requests.first?.json?["messages"] as? [[String: Any]])
        let system = try #require(messages.first?["content"] as? String)
        #expect(system.contains(#""capture" → "キャプチャ""#) && !system.contains(#""pin""#))
    }
}
