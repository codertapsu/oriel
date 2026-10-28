import Foundation
@testable import OrielTranslation
import Testing

struct DeepLProviderTests {
    private func provider(
        _ server: StubServer?,
        key: String? = "deepl-test-key",
        formality: ProviderConfig.Formality = .automatic
    ) -> DeepLProvider {
        let config = ProviderConfig(id: "deepl", kind: .deepl, baseURL: server?.baseURL ?? "", formality: formality)
        return DeepLProvider(config: config, apiKey: APIKey(key), http: server?.http ?? HTTPClient(session: StubURLProtocol.session))
    }

    private func echoServer() -> StubServer {
        StubServer { request in
            let texts = request.json?["text"] as? [String] ?? []
            return .json(TestSupport.json(["translations": texts.map { ["detected_source_language": "JA", "text": "en:\($0)"] }]))
        }
    }

    @Test func sendsTheBatchWithTheAuthKeyHeader() async throws {
        let server = echoServer()
        let request = TestSupport.request(["こんにちは", "世界"], source: "ja", target: "en")
        let result = try await TestSupport.collect(provider(server, formality: .more).translate(request))
        let recorded = try #require(server.requests.first)
        #expect(recorded.method == "POST" && recorded.url.path == "/v2/translate")
        #expect(recorded.header("Authorization") == "DeepL-Auth-Key deepl-test-key")
        let body = try #require(recorded.json)
        #expect(body["text"] as? [String] == ["こんにちは", "世界"])
        #expect(body["target_lang"] as? String == "EN-US")
        #expect(body["source_lang"] as? String == "JA")
        #expect(body["formality"] as? String == "prefer_more")
        #expect(body["preserve_formatting"] as? Bool == true)
        #expect(result.translations == [1: "en:こんにちは", 2: "en:世界"])
        #expect(result.usage == TranslationUsage(characters: 7))
    }

    @Test func leavesFormalityOutByDefaultAndBatchesByFifty() async throws {
        let server = echoServer()
        let texts = (1 ... 120).map { "Line \($0)" }
        _ = try await TestSupport.collect(provider(server).translate(TestSupport.request(texts)))
        #expect(server.requests.map { ($0.json?["text"] as? [String])?.count } == [50, 50, 20])
        #expect(server.requests.first?.json?["formality"] == nil)
    }

    @Test(arguments: [
        ("en", "EN-US"), ("en-GB", "EN-GB"), ("pt", "PT-BR"), ("pt-PT", "PT-PT"), ("zh", "ZH-HANS"), ("zh-Hant", "ZH-HANT"),
        ("zh-TW", "ZH-HANT"), ("ja", "JA"), ("nb", "NB"),
    ])
    func usesDeepLsTargetCodes(_ language: String, _ code: String) {
        #expect(DeepLProvider.targetCode(for: Locale.Language(identifier: language)) == code)
    }

    @Test func usesTheFreeAPIForFreeKeys() {
        #expect(provider(nil, key: "abc:fx").url(path: "translate")?.absoluteString == "https://api-free.deepl.com/v2/translate")
        #expect(provider(nil, key: "abc").url(path: "translate")?.absoluteString == "https://api.deepl.com/v2/translate")
    }

    @Test(arguments: [
        (
            403,
            #"{"message":"Wrong endpoint. Use https://api.deepl.com"}"#,
            TranslationFailure.unauthorized("Wrong endpoint. Use https://api.deepl.com")
        ),
        (456, #"{"message":"Quota exceeded"}"#, .quotaExceeded("Quota exceeded")),
        (429, #"{"message":"Too many requests"}"#, .rateLimited(retryAfter: nil)),
        (413, "", .badResponse("The request is too large for the provider.")),
    ])
    func mapsErrors(status: Int, body: String, expected: TranslationFailure) async {
        let server = StubServer { _ in .json(body, status: status) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == expected)
    }

    @Test func sTheKeyAgainstTheUsageEndpoint() async throws {
        let server = StubServer { _ in .json(#"{"character_count":180118,"character_limit":500000}"#) }
        let summary = try await provider(server).testConnection()
        #expect(summary.hasPrefix("Connected · ") && summary.contains("characters used"))
        #expect(server.requests.first?.url.path == "/v2/usage")
        #expect(await provider(server, key: nil).availability() == .missingAPIKey)
    }
}
