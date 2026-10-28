import Foundation
@testable import OrielTranslation
import Security
import Synchronization
import Testing

/// Google glossaries (PLAN §7.7.2): Cloud Translation Advanced (v3) with an OAuth token for a service account key,
/// because v3 takes no API keys. Every key is made during the test.
struct GoogleGlossaryTests {
    private static let glossary = "projects/p1/locations/us-central1/glossaries/terms"

    /// A clock the tests move by hand.
    private final class Clock: Sendable {
        private let date = Mutex(Date(timeIntervalSince1970: 1_800_000_000))

        var now: Date {
            date.withLock { $0 }
        }

        func advance(by seconds: TimeInterval) {
            date.withLock { $0 = $0.addingTimeInterval(seconds) }
        }
    }

    /// Answers the token service at `/token` and v3 at `/v3/…`; v3 answers with the texts tagged.
    private func server(tokenStatus: Int = 200) -> StubServer {
        StubServer { request in
            if request.url.path == "/token" {
                guard tokenStatus == 200 else {
                    return .json(#"{"error":"invalid_grant","error_description":"Invalid JWT Signature."}"#, status: tokenStatus)
                }
                return .json(#"{"access_token":"ya29.test","expires_in":3599,"token_type":"Bearer"}"#)
            }
            if request.method == "GET" {
                return .json(#"{"name":"projects/p1/locations/us-central1/glossaries/terms","entryCount":42}"#)
            }
            let texts = request.json?["contents"] as? [String] ?? []
            var answer: [String: Any] = ["translations": texts.map { ["translatedText": "plain:\($0)"] }]
            if request.json?["glossaryConfig"] != nil {
                answer["glossaryTranslations"] = texts.map { ["translatedText": "glossary:\($0)"] }
            }
            return .json(TestSupport.json(answer))
        }
    }

    private func provider(
        _ server: StubServer,
        glossary: String = Self.glossary,
        account: GoogleServiceAccount?,
        tokens: GoogleAccessTokens = GoogleAccessTokens()
    ) -> GoogleTranslateProvider {
        let config = ProviderConfig(
            id: "google", kind: .google, baseURL: "\(server.baseURL)/language/translate/v2", glossaryResource: glossary
        )
        return GoogleTranslateProvider(config: config, apiKey: nil, http: server.http, serviceAccount: account, tokens: tokens)
    }

    private func account(for server: StubServer) throws -> (GoogleServiceAccount, TestServiceAccount.Made) {
        let made = try TestServiceAccount.make(tokenURL: "\(server.baseURL)/token")
        return try (GoogleServiceAccount(json: made.json), made)
    }

    // MARK: - Keys

    @Test func rsaKeysReadFromPKCS8AndPKCS1() throws {
        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.example/token")
        for pem in [made.pkcs8PEM, made.pkcs1PEM] {
            let key = try PrivateKeyPEM.rsaKey(from: pem)
            let message = Data("hello".utf8) as CFData
            let signature = try #require(SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, message, nil))
            #expect(SecKeyVerifySignature(made.publicKey, .rsaSignatureMessagePKCS1v15SHA256, message, signature, nil))
        }
    }

    @Test func otherPEMIsRefused() throws {
        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.example/token")
        let certificate = made.pkcs8PEM.replacingOccurrences(of: "PRIVATE KEY", with: "CERTIFICATE")
        let ecOID: [UInt8] = [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
        let ecKey = TestServiceAccount.der(
            0x30, TestServiceAccount.der(0x02, [0]) + TestServiceAccount.der(0x30, ecOID) + TestServiceAccount.der(0x04, [1, 2, 3])
        )
        for pem in ["not a key", certificate, TestServiceAccount.pem("PRIVATE KEY", Data(ecKey))] {
            #expect(throws: TranslationFailure.self) { try PrivateKeyPEM.rsaKey(from: pem) }
        }
        #expect(PrivateKeyPEM.pkcs1Key(fromPKCS8: Data([0x30, 0x84, 0xFF, 0xFF, 0xFF, 0xFF])) == nil)
    }

    @Test func keyFilesAreCheckedAndNeverPrinted() throws {
        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.googleapis.com/token")
        let account = try GoogleServiceAccount(json: made.json)
        #expect(account.clientEmail == "oriel@test-project.iam.gserviceaccount.com")
        #expect(account.projectID == "test-project")
        #expect(account.tokenURL.absoluteString == "https://oauth2.googleapis.com/token")
        #expect("\(account)" == "<service account>" && String(reflecting: account) == "<service account>")
        #expect(!String(describing: Mirror(reflecting: account).children.map(\.value)).contains("PRIVATE"))

        let object = try #require(try JSONSerialization.jsonObject(with: Data(made.json.utf8)) as? [String: String])
        let broken: [[String: String]] = [
            object.merging(["type": "authorized_user"]) { $1 },
            object.filter { $0.key != "private_key" },
            object.merging(["token_uri": "http://oauth2.example/token"]) { $1 },
            object.merging(["private_key": "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----"]) { $1 },
        ]
        for file in broken {
            #expect(throws: TranslationFailure.self) { try GoogleServiceAccount(json: TestSupport.json(file)) }
        }
        #expect(throws: TranslationFailure.self) { try GoogleServiceAccount(json: "{ not json") }
    }

    // MARK: - Tokens

    @Test func theAssertionIsAJWTSignedForCloudTranslation() throws {
        let made = try TestServiceAccount.make(tokenURL: "https://oauth2.googleapis.com/token")
        let account = try GoogleServiceAccount(json: made.json)
        let jwt = try GoogleAccessTokens.assertion(for: account, issuedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let parts = try TestServiceAccount.decode(jwt: jwt)
        #expect(parts.header["alg"] as? String == "RS256" && parts.header["typ"] as? String == "JWT")
        #expect(parts.claims["iss"] as? String == account.clientEmail)
        #expect(parts.claims["aud"] as? String == "https://oauth2.googleapis.com/token")
        #expect(parts.claims["scope"] as? String == "https://www.googleapis.com/auth/cloud-translation")
        #expect(parts.claims["iat"] as? Int == 1_800_000_000 && parts.claims["exp"] as? Int == 1_800_003_600)
        #expect(SecKeyVerifySignature(
            made.publicKey, .rsaSignatureMessagePKCS1v15SHA256, parts.signingInput as CFData, parts.signature as CFData, nil
        ))
        #expect(!jwt.contains("=") && !jwt.contains("+") && !jwt.contains("/"))
    }

    @Test func tokensAreFetchedOnceAndRenewedBeforeTheyRunOut() async throws {
        let server = server()
        let (account, _) = try account(for: server)
        let clock = Clock()
        let tokens = GoogleAccessTokens { clock.now }
        #expect(try await tokens.token(for: account, http: server.http, timeout: 10) == "ya29.test")
        let request = try #require(server.requests.first)
        #expect(request.method == "POST" && request.header("Content-Type") == "application/x-www-form-urlencoded")
        var form = URLComponents()
        form.percentEncodedQuery = String(data: request.body, encoding: .utf8)
        let fields = Dictionary(uniqueKeysWithValues: (form.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(fields["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer")
        #expect(try TestServiceAccount.decode(jwt: #require(fields["assertion"])).claims["iss"] as? String == account.clientEmail)

        clock.advance(by: 3000)
        _ = try await tokens.token(for: account, http: server.http, timeout: 10)
        #expect(server.requests.count == 1)
        clock.advance(by: 560) // 39 s left: too close
        _ = try await tokens.token(for: account, http: server.http, timeout: 10)
        #expect(server.requests.count == 2)
    }

    @Test func aRefusedKeySaysWhy() async throws {
        let server = server(tokenStatus: 400)
        let (account, _) = try account(for: server)
        let failure = await TestSupport.failure(of: provider(server, account: account).translate(TestSupport.request(["Hello"])))
        #expect(failure == .unauthorized("Google refused the service account key: Invalid JWT Signature."))
    }

    // MARK: - Translating

    @Test func glossariesUseV3WithABearerToken() async throws {
        let server = server()
        let (account, _) = try account(for: server)
        let result = try await TestSupport.collect(provider(server, account: account).translate(TestSupport.request(
            ["Hello", "World"],
            target: "ja"
        )))
        let request = try #require(server.requests.last)
        #expect(request.method == "POST" && request.url.path == "/v3/projects/p1/locations/us-central1:translateText")
        #expect(request.header("Authorization") == "Bearer ya29.test" && request.header("X-Goog-Api-Key") == nil)
        let body = try #require(request.json)
        #expect(body["contents"] as? [String] == ["Hello", "World"])
        #expect(body["sourceLanguageCode"] as? String == "en" && body["targetLanguageCode"] as? String == "ja")
        #expect(body["mimeType"] as? String == "text/plain" && body["model"] == nil)
        #expect((body["glossaryConfig"] as? [String: Any])?["glossary"] as? String == Self.glossary)
        #expect(result.translations == [1: "glossary:Hello", 2: "glossary:World"])
        #expect(result.usage == TranslationUsage(characters: 10))
    }

    @Test func withoutAKnownSourceLanguageTheGlossaryIsLeftOut() async throws {
        let server = server()
        let (account, _) = try account(for: server)
        let result = try await TestSupport.collect(provider(server, account: account).translate(TestSupport.request(
            ["1234 5678"],
            source: nil
        )))
        let body = try #require(server.requests.last?.json)
        #expect(body["glossaryConfig"] == nil && body["sourceLanguageCode"] == nil)
        #expect(result.translations == [1: "plain:1234 5678"])
    }

    @Test(arguments: [
        ("terms", "test-project", "projects/test-project/locations/us-central1/glossaries/terms"),
        ("projects/p9/locations/europe-west1/glossaries/x", nil, "projects/p9/locations/europe-west1/glossaries/x"),
        ("  terms  ", "p1", "projects/p1/locations/us-central1/glossaries/terms"),
    ])
    func glossaryNamesResolve(_ text: String, _ project: String?, _ expected: String) {
        #expect(GoogleTranslateProvider.glossaryResource(text, projectID: project) == expected)
    }

    @Test func malformedGlossaryNamesAreRefused() {
        for text in ["", "projects/p1/glossaries/x", "projects//locations/l/glossaries/x", "a/b"] {
            #expect(GoogleTranslateProvider.glossaryResource(text, projectID: "p1") == nil)
        }
        #expect(GoogleTranslateProvider.glossaryResource("terms", projectID: nil) == nil)
        #expect(GoogleTranslateProvider.parent(ofGlossary: Self.glossary) == "projects/p1/locations/us-central1")
    }

    @Test func availabilitySaysWhatAGlossaryNeeds() async throws {
        let server = server()
        let (account, _) = try account(for: server)
        guard case .notConfigured = await provider(server, account: nil).availability() else {
            Issue.record("a glossary without a service account should need setting up")
            return
        }
        guard case .notConfigured = await provider(server, glossary: "projects/p1/x", account: account).availability() else {
            Issue.record("a malformed glossary should need setting up")
            return
        }
        // v3 needs no API key.
        #expect(await provider(server, account: account).availability() == .available)
        #expect(await provider(server, glossary: "", account: account).availability() == .missingAPIKey)
    }

    @Test func aConnectionCheckReadsTheGlossary() async throws {
        let server = server()
        let (account, _) = try account(for: server)
        #expect(try await provider(server, account: account).testConnection() == "Connected · glossary with 42 entries")
        #expect(server.requests.last?.url.path == "/v3/projects/p1/locations/us-central1/glossaries/terms")
        #expect(server.requests.last?.header("Authorization") == "Bearer ya29.test")
    }
}
