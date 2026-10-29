import Foundation
@testable import OrielTranslation
import Synchronization
import Testing

/// DeepL glossaries for glossary projects: made on first use, reused, replaced when the terms change, made again when
/// DeepL lost one, and placeholder tokens for pairs DeepL glossaries do not cover.
struct DeepLGlossaryTests {
    private static let project = UUID()

    /// Glossaries the stub created, and whether translations with `forgotten` ids should fail.
    private final class Account: Sendable {
        let created = Mutex<[[String: Any]]>([])
        let forgotten = Mutex<Set<String>>([])

        var createdCount: Int {
            created.withLock { $0.count }
        }
    }

    private func server(_ account: Account, pairs: [String] = ["en>ja", "en>de", "ja>en"]) -> StubServer {
        StubServer { request in
            switch (request.method, request.url.path) {
            case ("GET", "/v2/glossary-language-pairs"):
                let list = pairs.map { pair -> [String: String] in
                    let parts = pair.split(separator: ">").map(String.init)
                    return ["source_lang": parts[0], "target_lang": parts[1]]
                }
                return .json(TestSupport.json(["supported_languages": list]))
            case ("POST", "/v2/glossaries"):
                let number = account.created.withLock { created in
                    created.append(request.json ?? [:])
                    return created.count
                }
                return .json(TestSupport.json(["glossary_id": "g-\(number)", "ready": true, "entry_count": 1]), status: 201)
            case ("DELETE", _):
                return StubResponse(status: 204, headers: [:], chunks: [])
            default:
                let glossaryID = request.json?["glossary_id"] as? String
                if let glossaryID, account.forgotten.withLock({ $0.contains(glossaryID) }) {
                    return .json(#"{"message":"Glossary not found"}"#, status: 404)
                }
                let texts = request.json?["text"] as? [String] ?? []
                return .json(TestSupport.json(["translations": texts.map { ["text": "ja:\($0)"] }]))
            }
        }
    }

    private func provider(_ server: StubServer, book: DeepLGlossaryBook?) -> DeepLProvider {
        let config = ProviderConfig(id: "deepl", kind: .deepl, baseURL: server.baseURL)
        return DeepLProvider(config: config, apiKey: APIKey("deepl-key"), http: server.http, glossaries: book)
    }

    private func request(_ texts: [String], terms: [GlossaryTerm], source: String? = "en", target: String = "ja") -> TranslationRequest {
        var request = TestSupport.request(texts, source: source, target: target)
        request.glossary = TranslationGlossary(projectID: Self.project, projectName: "Docs", terms: terms)
        return request
    }

    private let capture = GlossaryTerm(source: "capture", target: "キャプチャ")

    @Test func makesTheGlossaryOnFirstUseAndReusesIt() async throws {
        let account = Account()
        let server = server(account)
        let saved = Mutex<DeepLGlossaryBook.Records>([:])
        let book = DeepLGlossaryBook { records in saved.withLock { $0 = records } }
        let first = try await TestSupport.collect(provider(server, book: book).translate(request(
            ["Open the capture panel"],
            terms: [capture]
        )))
        #expect(first.translations == [1: "ja:Open the capture panel"])

        let created = try #require(account.created.withLock { $0.first })
        #expect(created["source_lang"] as? String == "en" && created["target_lang"] as? String == "ja")
        #expect(created["entries"] as? String == "capture\tキャプチャ" && created["entries_format"] as? String == "tsv")
        #expect(created["name"] as? String == "Oriel · Docs · en→ja")
        let translate = try #require(server.requests.last?.json)
        #expect(translate["glossary_id"] as? String == "g-1" && translate["source_lang"] as? String == "EN")
        #expect(saved.withLock { $0.values.map(\.glossaryID) } == ["g-1"])

        _ = try await TestSupport.collect(provider(server, book: book).translate(request(["Capture again"], terms: [capture])))
        #expect(account.createdCount == 1)
        #expect(server.requests.map(\.url.path) == ["/v2/glossary-language-pairs", "/v2/glossaries", "/v2/translate", "/v2/translate"])
    }

    @Test func changedTermsMakeANewGlossaryAndDeleteTheOldOne() async throws {
        let account = Account()
        let server = server(account)
        let book = DeepLGlossaryBook()
        _ = try await TestSupport.collect(provider(server, book: book).translate(request(["capture"], terms: [capture])))
        let more = [capture, GlossaryTerm(source: "pin", target: "ピン")]
        _ = try await TestSupport.collect(provider(server, book: book).translate(request(["capture"], terms: more)))
        #expect(account.createdCount == 2)
        #expect(server.requests.contains { $0.method == "DELETE" && $0.url.path == "/v2/glossaries/g-1" })
        #expect(server.requests.last?.json?["glossary_id"] as? String == "g-2")
    }

    @Test func aGlossaryDeepLNoLongerKnowsIsMadeAgainOnce() async throws {
        let account = Account()
        let server = server(account)
        let book = DeepLGlossaryBook()
        _ = try await TestSupport.collect(provider(server, book: book).translate(request(["capture"], terms: [capture])))
        _ = account.forgotten.withLock { $0.insert("g-1") }
        let result = try await TestSupport.collect(provider(server, book: book).translate(request(["capture it"], terms: [capture])))
        #expect(result.translations == [1: "ja:capture it"])
        #expect(server.requests.last?.json?["glossary_id"] as? String == "g-2")
    }

    @Test func pairsWithoutDeepLGlossariesProtectTheTermsWithTokens() async throws {
        let account = Account()
        let server = server(account, pairs: ["en>de"])
        let result = try await TestSupport.collect(provider(server, book: DeepLGlossaryBook()).translate(request(
            ["Open the capture panel"],
            terms: [capture]
        )))
        #expect(account.createdCount == 0)
        let translate = try #require(server.requests.last?.json)
        #expect(translate["text"] as? [String] == ["Open the [[1]] panel"] && translate["glossary_id"] == nil)
        #expect(result.translations == [1: "ja:Open the キャプチャ panel"])
    }

    @Test func aGlossaryNeedsTheSourceLanguageSoItIsDetected() async throws {
        let account = Account()
        let server = server(account)
        _ = try await TestSupport.collect(provider(server, book: DeepLGlossaryBook()).translate(request(
            ["Open the capture panel and pin the screenshot to the screen"],
            terms: [capture],
            source: nil
        )))
        #expect(account.createdCount == 1)
        #expect(server.requests.last?.json?["source_lang"] as? String == "EN")
    }

    @Test func withoutAGlossaryNothingChanges() async throws {
        let account = Account()
        let server = server(account)
        _ = try await TestSupport.collect(provider(server, book: DeepLGlossaryBook()).translate(TestSupport.request(["Hello"])))
        #expect(server.requests.map(\.url.path) == ["/v2/translate"])
        #expect(server.requests.first?.json?["glossary_id"] == nil)
    }

    @Test func entriesAreCleanedAndTheFirstOfEqualSourcesWins() throws {
        let glossary = TranslationGlossary(projectID: Self.project, projectName: " ", terms: [
            GlossaryTerm(source: " two\twords ", target: "deux\nmots"),
            GlossaryTerm(source: "two words", target: "doubled"),
            GlossaryTerm(source: "Pin", target: "ピン", isCaseSensitive: true),
            GlossaryTerm(source: "no target", target: ""),
        ])
        let spec = try #require(DeepLGlossarySpec(
            glossary: glossary, providerID: "deepl", source: Locale.Language(identifier: "en-GB"), target: Locale.Language(identifier: "nb")
        ))
        #expect(spec.entries == "two words\tdeux mots\nPin\tピン" && spec.entryCount == 2)
        #expect(spec.pairKey == "en>nb" && spec.name == "Oriel · Glossary · en→nb")
        #expect(DeepLGlossarySpec(
            glossary: .none,
            providerID: "deepl",
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ja")
        ) == nil)
    }
}
