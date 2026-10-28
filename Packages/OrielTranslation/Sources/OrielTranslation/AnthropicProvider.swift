import Foundation

/// Anthropic's Messages API (PLAN §7.7.2): `POST /v1/messages` with `x-api-key` and `anthropic-version`, streamed
/// with SSE, the capture as a base64 image block in AI Vision mode.
struct AnthropicProvider: TranslationProvider, ModelListing {
    let config: ProviderConfig
    let apiKey: APIKey?
    let http: HTTPClient

    /// The Messages API version header. A custom `anthropic-version` header overrides it.
    static let apiVersion = "2023-06-01"

    var id: ProviderID {
        config.id
    }

    var displayName: String {
        config.displayName
    }

    var capabilities: ProviderCapabilities {
        config.kind.capabilities
    }

    func availability() async -> ProviderAvailability {
        guard messagesURL != nil else { return .notConfigured("Enter an https:// address for the Anthropic API.") }
        guard !model.isEmpty else { return .notConfigured("Choose a model for \(config.displayName) in Settings → Translation.") }
        guard apiKey != nil else { return .missingAPIKey }
        return .available
    }

    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TranslationFailure.from(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func listModels() async throws -> [String] {
        guard let url = Endpoint.url(config.effectiveBaseURL, path: "models", versionPrefix: "v1") else {
            throw TranslationFailure.notConfigured("Enter the API address first.")
        }
        guard apiKey != nil else { throw TranslationFailure.missingAPIKey }
        let request = try HTTPClient.request(
            url,
            method: "GET",
            headers: headers,
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        return try JSONDecoder().decode(AnthropicModelList.self, from: data).data.map(\.id)
    }

    func testConnection() async throws -> String {
        switch await availability() {
        case .missingAPIKey: throw TranslationFailure.missingAPIKey
        case let .notConfigured(detail): throw TranslationFailure.notConfigured(detail)
        default: break
        }
        let models = try await listModels()
        return models.contains(model) ? "Connected · “\(model)” is available" : "Connected, but the API doesn't list “\(model)”."
    }

    // MARK: - Requests

    private var model: String {
        config.model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var messagesURL: URL? {
        Endpoint.url(config.effectiveBaseURL, path: "messages", versionPrefix: "v1")
    }

    private var headers: [String: String] {
        var headers = ["anthropic-version": Self.apiVersion]
        headers["x-api-key"] = apiKey?.value
        return headers
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let url = messagesURL else { throw TranslationFailure.notConfigured("Enter an https:// address for the Anthropic API.") }
        guard apiKey != nil else { throw TranslationFailure.missingAPIKey }
        guard !model.isEmpty else { throw TranslationFailure.notConfigured("Choose a model for \(config.displayName).") }
        var headers = headers
        headers["Accept"] = "text/event-stream"
        let urlRequest = try HTTPClient.request(
            url,
            json: body(for: request),
            headers: headers,
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (bytes, response) = try await http.stream(urlRequest, kind: config.kind)
        var emitter = SegmentEmitter(continuation: continuation, expectedIDs: request.segments.map(\.id))
        var usage = TranslationUsage(characters: request.characterCount)
        if HTTPClient.isJSON(response) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            try Self.apply(JSONDecoder().decode(AnthropicEvent.self, from: data), emitter: &emitter, usage: &usage)
        } else {
            var events = SSEParser()
            var finished = false
            try await HTTPClient.forEachLine(in: bytes) { line in
                guard let event = events.feed(line: line) else { return true }
                finished = try Self.handle(event, emitter: &emitter, usage: &usage)
                return !finished
            }
            if !finished, let event = events.finish() {
                _ = try Self.handle(event, emitter: &emitter, usage: &usage)
            }
        }
        emitter.finish()
        continuation.yield(.usage(usage))
    }

    /// Returns true on `message_stop`.
    private static func handle(_ event: SSEParser.Event, emitter: inout SegmentEmitter, usage: inout TranslationUsage) throws -> Bool {
        guard let decoded = try? JSONDecoder().decode(AnthropicEvent.self, from: Data(event.data.utf8)) else { return false }
        try apply(decoded, emitter: &emitter, usage: &usage)
        return decoded.type == "message_stop"
    }

    private static func apply(_ event: AnthropicEvent, emitter: inout SegmentEmitter, usage: inout TranslationUsage) throws {
        switch event.type {
        case "message_start":
            usage.inputTokens = event.message?.usage?.inputTokens ?? usage.inputTokens
        case "content_block_delta":
            if event.delta?.type == "text_delta", let text = event.delta?.text {
                emitter.feed(text)
            }
        case "message_delta":
            usage.outputTokens = event.usage?.outputTokens ?? usage.outputTokens
        case "message":
            // A whole answer, from a server that ignored `stream`.
            emitter.feed(event.content?.compactMap(\.text).joined() ?? "")
            usage.inputTokens = event.usage?.inputTokens ?? 0
            usage.outputTokens = event.usage?.outputTokens ?? 0
        case "error":
            throw failure(type: event.error?.type, message: event.error?.message)
        default:
            break
        }
    }

    /// Errors that arrive inside an otherwise successful stream (`event: error`).
    static func failure(type: String?, message: String?) -> TranslationFailure {
        let message = message ?? "Unknown error"
        switch type {
        case "overloaded_error": return .server(status: 529, message: message)
        case "rate_limit_error": return .rateLimited(retryAfter: nil)
        case "authentication_error", "permission_error": return .unauthorized(message)
        case "not_found_error": return .modelUnavailable("Not found on the server: \(message)")
        case "api_error": return .server(status: 500, message: message)
        default: return .badResponse(message)
        }
    }

    private func body(for request: TranslationRequest) -> [String: Any] {
        var content: [[String: Any]] = []
        if let image = request.image.flatMap({ ImageEncoder.encodeForVision($0) }) {
            content.append(["type": "image", "source": ["type": "base64", "media_type": image.mediaType, "data": image.base64]])
        }
        content.append(["type": "text", "text": SegmentPrompt.segmentsJSON(request.segments)])
        var body: [String: Any] = [
            "model": model,
            "max_tokens": max(256, config.maxOutputTokens),
            "stream": true,
            "system": SegmentPrompt.instructions(for: request),
            "messages": [["role": "user", "content": content]],
        ]
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }
        return body
    }
}

private struct AnthropicModelList: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

/// One SSE event's data (`message_start`, `content_block_delta`, `message_delta`, `message_stop`, `error`), or a
/// whole non-streamed message (`type: "message"`).
private struct AnthropicEvent: Decodable {
    let type: String
    let message: AnthropicMessageStart?
    let delta: AnthropicDelta?
    let usage: AnthropicUsage?
    let error: AnthropicErrorBody?
    let content: [AnthropicDelta]?
}

private struct AnthropicMessageStart: Decodable {
    let usage: AnthropicUsage?
}

private struct AnthropicDelta: Decodable {
    let type: String?
    let text: String?
}

private struct AnthropicUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// `{"type": "overloaded_error", "message": "Overloaded"}`.
private struct AnthropicErrorBody: Decodable {
    let type: String?
    let message: String?
}
