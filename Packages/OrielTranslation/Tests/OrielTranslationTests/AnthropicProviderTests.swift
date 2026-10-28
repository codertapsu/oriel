import Foundation
@testable import OrielTranslation
import Testing

struct AnthropicProviderTests {
    private func provider(_ server: StubServer, key: String? = "sk-ant-test", headers: [String: String] = [:]) -> AnthropicProvider {
        let config = ProviderConfig(
            id: "anthropic", kind: .anthropic, baseURL: server.baseURL, model: "claude-test-model", customHeaders: headers,
            maxOutputTokens: 2048
        )
        return AnthropicProvider(config: config, apiKey: APIKey(key), http: server.http)
    }

    /// A Messages API event stream that carries `text` in deltas of `pieceLength` characters.
    private func stream(_ text: String, pieceLength: Int = 6) -> String {
        var events = [
            (
                "message_start",
                #"{"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","#
                    + #""usage":{"input_tokens":31,"output_tokens":1}}}"#
            ),
            ("content_block_start", #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#),
            ("ping", #"{"type":"ping"}"#),
        ]
        let characters = Array(text)
        for start in stride(from: 0, to: characters.count, by: pieceLength) {
            let piece = String(characters[start ..< min(start + pieceLength, characters.count)])
            let delta: [String: Any] = ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": piece]]
            events.append(("content_block_delta", TestSupport.json(delta)))
        }
        events += [
            ("content_block_stop", #"{"type":"content_block_stop","index":0}"#),
            ("message_delta", #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":12}}"#),
            ("message_stop", #"{"type":"message_stop"}"#),
        ]
        return events.map { "event: \($0.0)\ndata: \($0.1)\n\n" }.joined()
    }

    private let answer = #"[{"id": 1, "translation": "Bonjour le monde"}, {"id": 2, "translation": "Bon matin"}]"#

    @Test func sendsAMessagesRequest() async throws {
        let server = StubServer { [answer] _ in .events(stream(answer)) }
        _ = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello world", "Good morning"])))
        let request = try #require(server.requests.first)
        #expect(request.method == "POST" && request.url.path == "/v1/messages")
        #expect(request.header("x-api-key") == "sk-ant-test")
        #expect(request.header("anthropic-version") == "2023-06-01")
        #expect(request.header("Content-Type") == "application/json")
        let body = try #require(request.json)
        #expect(body["model"] as? String == "claude-test-model")
        #expect(body["max_tokens"] as? Int == 2048)
        #expect(body["stream"] as? Bool == true)
        #expect(body["temperature"] == nil)
        #expect((body["system"] as? String)?.contains("French") == true)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1 && messages[0]["role"] as? String == "user")
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(content.map { $0["type"] as? String } == ["text"])
        #expect(content[0]["text"] as? String == #"[{"id":1,"text":"Hello world"},{"id":2,"text":"Good morning"}]"#)
    }

    @Test func sendsTheCaptureAsABase64ImageBlockBeforeTheText() async throws {
        let server = StubServer { [answer] _ in .events(stream(answer)) }
        _ = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello"], image: TestSupport.image())))
        let messages = try #require(server.requests.first?.json?["messages"] as? [[String: Any]])
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(content.map { $0["type"] as? String } == ["image", "text"])
        let source = try #require(content[0]["source"] as? [String: Any])
        #expect(source["type"] as? String == "base64" && source["media_type"] as? String == "image/png")
        let data = try #require(source["data"] as? String)
        #expect(Data(base64Encoded: data) != nil)
    }

    @Test func streamsTextDeltasIntoSegmentsAndReportsUsage() async throws {
        let server = StubServer { [answer] _ in .events(stream(answer, pieceLength: 4), chunkSize: 13) }
        let result = try await TestSupport.collect(provider(server).translate(TestSupport.request(["Hello world", "Good morning"])))
        #expect(result.translations == [1: "Bonjour le monde", 2: "Bon matin"])
        #expect(result.usage == TranslationUsage(characters: 23, inputTokens: 31, outputTokens: 12))
    }

    @Test func failsOnAnErrorEventInsideTheStream() async {
        let body = "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":3}}}\n\n"
            + "event: error\ndata: {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}\n\n"
        let server = StubServer { _ in .events(body) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == .server(
            status: 529,
            message: "Overloaded"
        ))
    }

    @Test(arguments: [
        (
            401,
            #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#,
            TranslationFailure.unauthorized("invalid x-api-key")
        ),
        (529, #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#, .server(status: 529, message: "Overloaded")),
        (
            404,
            #"{"type":"error","error":{"type":"not_found_error","message":"model: nope"}}"#,
            .modelUnavailable("Not found on the server: model: nope")
        ),
    ])
    func mapsHTTPErrors(status: Int, body: String, expected: TranslationFailure) async {
        let server = StubServer { _ in .json(body, status: status) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == expected)
    }

    @Test func mapsRateLimitsWithRetryAfter() async {
        let server = StubServer { _ in .json(
            #"{"type":"error","error":{"type":"rate_limit_error","message":"slow"}}"#,
            status: 429,
            headers: ["retry-after": "7"]
        ) }
        #expect(await TestSupport.failure(of: provider(server).translate(TestSupport.request(["Hello"]))) == .rateLimited(retryAfter: 7))
    }

    @Test func needsAKeyAndLetsCustomHeadersOverrideTheVersion() async throws {
        let server = StubServer { [answer] _ in .events(stream(answer)) }
        #expect(await provider(server, key: nil).availability() == .missingAPIKey)
        #expect(await TestSupport.failure(of: provider(server, key: nil).translate(TestSupport.request(["Hello"]))) == .missingAPIKey)
        #expect(server.requests.isEmpty)
        _ = try await TestSupport
            .collect(provider(server, headers: ["anthropic-version": "2099-01-01"]).translate(TestSupport.request(["Hello"])))
        #expect(server.requests.first?.header("anthropic-version") == "2099-01-01")
    }

    @Test func listsModels() async throws {
        let server = StubServer { _ in .json(#"{"data":[{"id":"claude-test-model","type":"model"}],"has_more":false}"#) }
        #expect(try await provider(server).listModels() == ["claude-test-model"])
        let request = try #require(server.requests.first)
        #expect(request.method == "GET" && request.url.path == "/v1/models" && request.header("x-api-key") == "sk-ant-test")
    }
}
