import Foundation
import OrielCore

/// One implementation for every `/v1/chat/completions` server (PLAN §7.7.2): OpenAI, Ollama, LM Studio and llama.cpp.
///
/// Streams with SSE and parses segments as they arrive; asks for a JSON schema (`response_format`) and repeats the
/// request without it when a server or model refuses; sends the capture as an `image_url` part in AI Vision mode;
/// reads a plain JSON answer when a server ignores `stream`.
struct OpenAICompatibleProvider: TranslationProvider, ModelListing {
    let config: ProviderConfig
    let apiKey: APIKey?
    let http: HTTPClient

    private static let log = Log.logger("translation")
    /// Text-only answers are split into requests of at most this many segments and characters, so a long capture
    /// does not hit a local model's context limit.
    private static let batchLimits = (count: 80, characters: 8000)

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
        guard let url = completionsURL else {
            return .notConfigured("Enter the server's address, for example http://localhost:11434/v1.")
        }
        guard !model.isEmpty else { return .notConfigured("Choose a model for \(config.displayName) in Settings → Translation.") }
        if url.host?.lowercased() == "api.openai.com", apiKey == nil {
            return .missingAPIKey
        }
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
            throw TranslationFailure.notConfigured("Enter the server's address first.")
        }
        let request = try HTTPClient.request(
            url,
            method: "GET",
            headers: authorization,
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let list = try JSONDecoder().decode(ModelList.self, from: data)
        return Array(Set(list.data.map(\.id))).sorted()
    }

    func testConnection() async throws -> String {
        if case let .notConfigured(detail) = await availability() {
            throw TranslationFailure.notConfigured(detail)
        }
        let models = try await listModels()
        guard !model.isEmpty, !models.isEmpty else { return "Connected · \(models.count) models" }
        return models.contains(model)
            ? "Connected · “\(model)” is available"
            : "Connected, but the server doesn't list “\(model)”. It has: \(models.prefix(8).joined(separator: ", "))"
    }

    // MARK: - Requests

    private var model: String {
        config.model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var completionsURL: URL? {
        Endpoint.url(config.effectiveBaseURL, path: "chat/completions", versionPrefix: "v1")
    }

    private var authorization: [String: String] {
        apiKey.map { ["Authorization": "Bearer \($0.value)"] } ?? [:]
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let url = completionsURL else { throw TranslationFailure.notConfigured("Enter the server's address.") }
        guard !model.isEmpty else { throw TranslationFailure.notConfigured("Choose a model for \(config.displayName).") }
        let image = request.image.flatMap { ImageEncoder.encodeForVision($0) }
        let batches = image == nil
            ? SegmentBatcher.batches(request.segments, maxCount: Self.batchLimits.count, maxCost: Self.batchLimits.characters)
            : [request.segments]
        var usage = TranslationUsage(characters: request.characterCount)
        for batch in batches {
            try Task.checkCancellation()
            var part = request
            part.segments = batch
            let tokens = try await stream(part, image: image, url: url, structured: config.usesStructuredOutput, continuation: continuation)
            usage.inputTokens += tokens.input
            usage.outputTokens += tokens.output
        }
        continuation.yield(.usage(usage))
    }

    private func stream(
        _ request: TranslationRequest,
        image: ImageEncoder.Encoded?,
        url: URL,
        structured: Bool,
        continuation: SegmentEmitter.Continuation
    ) async throws -> (input: Int, output: Int) {
        var headers = authorization
        headers["Accept"] = "text/event-stream"
        let urlRequest = try HTTPClient.request(
            url, json: body(for: request, image: image, structured: structured), headers: headers, custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let bytes: URLSession.AsyncBytes
        let response: HTTPURLResponse
        do {
            (bytes, response) = try await http.stream(urlRequest, kind: config.kind)
        } catch let failure as TranslationFailure where structured && failure.isRejectedRequest {
            Self.log.info("\(config.id.rawValue, privacy: .public) refused the JSON schema; asking again without it")
            return try await stream(request, image: image, url: url, structured: false, continuation: continuation)
        }
        var emitter = SegmentEmitter(continuation: continuation, expectedIDs: request.segments.map(\.id))
        var tokens = (input: 0, output: 0)
        if HTTPClient.isJSON(response) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
            }
            let completion = try JSONDecoder().decode(ChatChunk.self, from: data)
            try completion.throwIfError()
            emitter.feed(completion.choices?.compactMap { $0.message?.content ?? $0.delta?.content }.joined() ?? "")
            tokens = completion.usage?.tokens ?? tokens
        } else {
            var events = SSEParser()
            var finished = false
            try await HTTPClient.forEachLine(in: bytes) { line in
                guard let event = events.feed(line: line) else { return true }
                finished = try Self.handle(event, emitter: &emitter, tokens: &tokens)
                return !finished
            }
            if !finished, let event = events.finish() {
                _ = try Self.handle(event, emitter: &emitter, tokens: &tokens)
            }
        }
        emitter.finish()
        return tokens
    }

    /// Returns true when the stream is done (`[DONE]`).
    private static func handle(
        _ event: SSEParser.Event,
        emitter: inout SegmentEmitter,
        tokens: inout (input: Int, output: Int)
    ) throws -> Bool {
        let data = event.data.trimmingCharacters(in: .whitespacesAndNewlines)
        if data == "[DONE]" {
            return true
        }
        // Keep-alives and anything else that is not a chunk are skipped.
        guard let chunk = try? JSONDecoder().decode(ChatChunk.self, from: Data(data.utf8)) else { return false }
        try chunk.throwIfError()
        for choice in chunk.choices ?? [] {
            if let content = choice.delta?.content ?? choice.message?.content {
                emitter.feed(content)
            }
        }
        if let usage = chunk.usage?.tokens {
            tokens = usage
        }
        return false
    }

    private func body(for request: TranslationRequest, image: ImageEncoder.Encoded?, structured: Bool) -> [String: Any] {
        let segments = SegmentPrompt.segmentsJSON(request.segments)
        let userContent: Any = if let image {
            [["type": "text", "text": segments], ["type": "image_url", "image_url": ["url": image.dataURL]]] as [[String: Any]]
        } else {
            segments
        }
        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "stream_options": ["include_usage": true],
            "messages": [
                ["role": "system", "content": SegmentPrompt.instructions(for: request)],
                ["role": "user", "content": userContent],
            ],
        ]
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }
        if structured {
            body["response_format"] = SegmentPrompt.responseFormat(includesSource: image != nil)
        }
        return body
    }
}

private struct ModelList: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

/// A streamed chunk (`choices[].delta`) or a whole completion (`choices[].message`), with usage and errors.
private struct ChatChunk: Decodable {
    let choices: [ChatChoice]?
    let usage: ChatUsage?
    let error: ServerMessage?

    func throwIfError() throws {
        if let message = error?.message {
            throw TranslationFailure.badResponse(message)
        }
    }
}

private struct ChatChoice: Decodable {
    let delta: ChatContent?
    let message: ChatContent?
}

private struct ChatContent: Decodable {
    let content: String?
}

private struct ChatUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?

    var tokens: (input: Int, output: Int) {
        (promptTokens ?? 0, completionTokens ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}
