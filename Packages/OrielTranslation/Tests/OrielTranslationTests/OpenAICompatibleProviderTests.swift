import Foundation
@testable import OrielTranslation
import Testing

struct OpenAICompatibleProviderTests {
    private let answer = #"{"translations": [{"id": 1, "translation": "Bonjour le monde"}, {"id": 2, "translation": "Bon matin"}]}"#

    private func provider(
        _ server: StubServer,
        key: String? = "sk-test",
        configure: (inout ProviderConfig) -> Void = { _ in }
    ) -> OpenAICompatibleProvider {
        var config = ProviderConfig(
            id: "ollama", kind: .openAICompatible, displayName: "Ollama", baseURL: "\(server.baseURL)/v1", model: "qwen2.5:7b"
        )
        configure(&config)
        return OpenAICompatibleProvider(config: config, apiKey: APIKey(key), http: server.http)
    }

    @Test func sendsAChatCompletionsRequest() async throws {
        let server = StubServer { [answer] _ in .events(TestSupport.openAIStream(answer)) }
        let provider = provider(server) { config in
            config.temperature = 0.2
            config.customHeaders = ["X-Team": "oriel"]
        }
        _ = try await TestSupport.collect(provider.translate(TestSupport.request(["Hello world", "Good morning"])))

        let request = try #require(server.requests.first)
        #expect(request.method == "POST")
        #expect(request.url.path == "/v1/chat/completions")
        #expect(request.header("Authorization") == "Bearer sk-test")
        #expect(request.header("Content-Type") == "application/json")
        #expect(request.header("Accept") == "text/event-stream")
        #expect(request.header("X-Team") == "oriel")
        let body = try #require(request.json)
        #expect(body["model"] as? String == "qwen2.5:7b")
        #expect(body["stream"] as? Bool == true)
        #expect(body["temperature"] as? Double == 0.2)
        #expect((body["stream_options"] as? [String: Any])?["include_usage"] as? Bool == true)
        #expect((body["response_format"] as? [String: Any])?["type"] as? String == "json_schema")
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user"])
        let instructions = try #require(messages[0]["content"] as? String)
        #expect(instructions.contains("French (fr)") && instructions.contains("same ids") && instructions.contains("English"))
        let segments = try #require(messages[1]["content"] as? String)
        #expect(segments == #"[{"id":1,"text":"Hello world"},{"id":2,"text":"Good morning"}]"#)
    }

    @Test func leavesOutTemperatureAndAuthorizationThatAreNotConfigured() async throws {
        let server = StubServer { [answer] _ in .events(TestSupport.openAIStream(answer)) }
        _ = try await TestSupport.collect(provider(server, key: nil).translate(TestSupport.request(["Hello world"])))
        let request = try #require(server.requests.first)
        #expect(request.header("Authorization") == nil)
        let body = try #require(request.json)
        #expect(body["temperature"] == nil)
    }

    @Test func streamsSegmentsAndUsage() async throws {
        let server = StubServer { [answer] _ in .events(TestSupport.openAIStream(answer, pieceLength: 3), chunkSize: 11) }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello world", "Good morning"])))
        #expect(result.translations == [1: "Bonjour le monde", 2: "Bon matin"])
        #expect(result.usage == TranslationUsage(characters: 23, inputTokens: 42, outputTokens: 17))
    }

    @Test func sendsTheCaptureAsADataURLInAIVisionMode() async throws {
        let server = StubServer { [answer] _ in .events(TestSupport.openAIStream(answer)) }
        let image = try TestSupport.image()
        _ = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello"], image: image)))
        let body = try #require(server.requests.first?.json)
        let messages = try #require(body["messages"] as? [[String: Any]])
        let parts = try #require(messages[1]["content"] as? [[String: Any]])
        #expect(parts.map { $0["type"] as? String } == ["text", "image_url"])
        let url = try #require((parts[1]["image_url"] as? [String: Any])?["url"] as? String)
        #expect(url.hasPrefix("data:image/png;base64,") && url.count > 40)
        let instructions = try #require(messages[0]["content"] as? String)
        #expect(instructions.contains("screenshot") && instructions.contains("1001"))
    }

    @Test func asksAgainWithoutTheSchemaWhenTheServerRefusesIt() async throws {
        let server = StubServer { [answer] request in
            if request.json?["response_format"] != nil {
                return .json(#"{"error":{"message":"response_format is not supported","type":"invalid_request_error"}}"#, status: 400)
            }
            return .events(TestSupport.openAIStream(answer))
        }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello world", "Good morning"])))
        #expect(result.translations.count == 2)
        #expect(server.requests.count == 2)
        #expect(server.requests.last?.json?["response_format"] == nil)
    }

    @Test func readsAPlainJSONAnswerFromAServerThatDoesNotStream() async throws {
        let completion: [String: Any] = [
            "choices": [["message": ["role": "assistant", "content": answer]]],
            "usage": ["prompt_tokens": 5, "completion_tokens": 6],
        ]
        let body = TestSupport.json(completion)
        let server = StubServer { _ in .json(body) }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello world", "Good morning"])))
        #expect(result.translations == [1: "Bonjour le monde", 2: "Bon matin"])
        #expect(result.usage?.outputTokens == 6)
    }

    @Test(arguments: [
        (401, #"{"error":{"message":"Incorrect API key provided"}}"#, TranslationFailure.unauthorized("Incorrect API key provided")),
        (
            404,
            #"{"error":{"message":"model 'nope' not found","type":"not_found_error"}}"#,
            .modelUnavailable("Not found on the server: model 'nope' not found")
        ),
        (500, #"{"error":"llama runner crashed"}"#, .server(status: 500, message: "llama runner crashed")),
        (400, #"{"error":{"message":"bad"}}"#, .server(status: 400, message: "bad")),
    ])
    func mapsHTTPErrors(status: Int, body: String, expected: TranslationFailure) async {
        let server = StubServer { _ in .json(body, status: status) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == expected)
    }

    @Test func mapsRateLimitsWithRetryAfter() async {
        let server = StubServer { _ in .json(#"{"error":{"message":"slow down"}}"#, status: 429, headers: ["Retry-After": "12"]) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == .rateLimited(retryAfter: 12))
    }

    @Test(arguments: [
        (URLError.Code.cannotConnectToHost, TranslationFailure.unreachable("Nothing answers at that address. Is the server running?")),
        (.notConnectedToInternet, .offline),
        (.timedOut, .timedOut),
    ])
    func mapsConnectionFailures(code: URLError.Code, expected: TranslationFailure) async {
        let server = StubServer { _ in .failure(code) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == expected)
    }

    @Test func failsOnAnErrorInsideTheEventStream() async {
        let server = StubServer { _ in .events("data: {\"error\":{\"message\":\"model crashed\"}}\n\n") }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == .badResponse("model crashed"))
    }

    @Test func splitsLongCapturesIntoSeveralRequests() async throws {
        let server = StubServer { request in
            let content = (request.json?["messages"] as? [[String: Any]])?.last?["content"] as? String ?? "[]"
            let ids = (try? JSONDecoder().decode([TranslationSegment].self, from: Data(content.utf8)))?.map(\.id) ?? []
            let answer = "[" + ids.map { "{\"id\":\($0),\"translation\":\"t\($0)\"}" }.joined(separator: ",") + "]"
            return .events(TestSupport.openAIStream(answer, pieceLength: 40, usage: (10, 5)))
        }
        let texts = (1 ... 100).map { "Line \($0)" }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(texts)))
        #expect(server.requests.count == 2)
        #expect(result.translations.count == 100 && result.translations[100] == "t100")
        #expect(result.usage?.inputTokens == 20 && result.usage?.outputTokens == 10)
    }

    @Test func listsTheServersModels() async throws {
        let server = StubServer { _ in .json(#"{"object":"list","data":[{"id":"qwen2.5:7b"},{"id":"llama3.2:3b"}]}"#) }
        let models = try await provider(server).listModels()
        #expect(models == ["llama3.2:3b", "qwen2.5:7b"])
        let request = try #require(server.requests.first)
        #expect(request.method == "GET" && request.url.path == "/v1/models")
        #expect(try await provider(server).testConnection() == "Connected · “qwen2.5:7b” is available")
    }

    @Test func needsAnEndpointAndAModelAndAKeyForOpenAI() async {
        let server = StubServer { _ in .json("{}") }
        #expect(await provider(server) { $0.model = "" }
            .availability() == .notConfigured("Choose a model for Ollama in Settings → Translation."))
        #expect(await provider(server) { $0.baseURL = "localhost" }.availability() != .available)
        #expect(await provider(server).availability() == .available)
        let openAI = OpenAICompatibleProvider(
            config: ProviderConfig(id: "openai", kind: .openAICompatible, baseURL: "https://api.openai.com/v1", model: "some-model"),
            apiKey: nil, http: server.http
        )
        #expect(await openAI.availability() == .missingAPIKey)
    }
}
