import Foundation
@testable import OrielTranslation
import Testing

struct GoogleTranslateProviderTests {
    private func provider(_ server: StubServer, key: String? = "AIza-test", model: String = "") -> GoogleTranslateProvider {
        let config = ProviderConfig(id: "google", kind: .google, baseURL: "\(server.baseURL)/language/translate/v2", model: model)
        return GoogleTranslateProvider(config: config, apiKey: APIKey(key), http: server.http)
    }

    /// Answers every request with the texts it got, tagged, the way v2 answers.
    private func echoServer() -> StubServer {
        StubServer { request in
            let texts = request.json?["q"] as? [String] ?? []
            let translations = texts.map { ["translatedText": "fr:\($0)", "detectedSourceLanguage": "en"] }
            return .json(TestSupport.json(["data": ["translations": translations]]))
        }
    }

    @Test func sendsTheKeyInAHeaderAndTheTextsInOneRequest() async throws {
        let server = echoServer()
        let result = try await TestSupport.collect(provider(server, model: "nmt").translate(TestSupport.request(
            ["Hello", "World"],
            target: "ja"
        )))
        let request = try #require(server.requests.first)
        #expect(request.method == "POST" && request.url.path == "/language/translate/v2")
        #expect(request.url.query == nil) // the key never goes in the URL
        #expect(request.header("X-Goog-Api-Key") == "AIza-test")
        let body = try #require(request.json)
        #expect(body["q"] as? [String] == ["Hello", "World"])
        #expect(body["target"] as? String == "ja")
        #expect(body["source"] as? String == "en")
        #expect(body["format"] as? String == "text")
        #expect(body["model"] as? String == "nmt")
        #expect(result.translations == [1: "fr:Hello", 2: "fr:World"])
        #expect(result.usage == TranslationUsage(characters: 10))
    }

    @Test func batchesLargeCaptures() async throws {
        let server = echoServer()
        let texts = (1 ... 130).map { "Line \($0)" }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(texts, source: nil)))
        #expect(server.requests.map { ($0.json?["q"] as? [String])?.count } == [100, 30])
        #expect(server.requests.first?.json?["source"] == nil)
        #expect(result.translations.count == 130 && result.translations[130] == "fr:Line 130")
    }

    @Test(arguments: [
        ("zh-Hant", "zh-TW"),
        ("zh-Hans", "zh-CN"),
        ("zh", "zh-CN"),
        ("pt-PT", "pt-PT"),
        ("pt-BR", "pt"),
        ("nb", "no"),
        ("ja", "ja"),
    ])
    func usesGooglesLanguageCodes(_ language: String, _ code: String) {
        #expect(GoogleTranslateProvider.code(for: Locale.Language(identifier: language)) == code)
    }

    @Test(arguments: [
        (
            400,
            #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#,
            TranslationFailure.unauthorized("API key not valid. Please pass a valid API key.")
        ),
        (
            403,
            #"{"error":{"code":403,"message":"Cloud Translation API has not been used in project 1"}}"#,
            .unauthorized("Cloud Translation API has not been used in project 1")
        ),
        (400, #"{"error":{"code":400,"message":"Invalid Value"}}"#, .server(status: 400, message: "Invalid Value")),
        (503, #"{"error":{"code":503,"message":"Backend Error"}}"#, .server(status: 503, message: "Backend Error")),
    ])
    func mapsErrors(status: Int, body: String, expected: TranslationFailure) async {
        let server = StubServer { _ in .json(body, status: status) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == expected)
    }

    @Test func rejectsAnAnswerWithTheWrongNumberOfTranslations() async {
        let server = StubServer { _ in .json(#"{"data":{"translations":[{"translatedText":"Bonjour"}]}}"#) }
        let failure = await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello", "World"])))
        #expect(failure == .badResponse("Google returned 1 translations for 2 texts."))
    }

    @Test func needsAKeyAndTestsItAgainstTheLanguageList() async throws {
        let server = StubServer { _ in .json(#"{"data":{"languages":[{"language":"en"},{"language":"ja"}]}}"#) }
        #expect(await provider(server, key: nil).availability() == .missingAPIKey)
        #expect(try await provider(server).testConnection() == "Connected · 2 languages")
        let request = try #require(server.requests.first)
        #expect(request.url.path == "/language/translate/v2/languages" && request.url.query == "target=en")
    }
}
