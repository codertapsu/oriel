import Foundation

/// DeepL's `/v2/translate` (PLAN §7.7.2), with `Authorization: DeepL-Auth-Key …`, batched texts and the formality
/// option. Free-plan keys (ending in `:fx`) use `api-free.deepl.com` unless an endpoint is configured.
struct DeepLProvider: TranslationProvider {
    let config: ProviderConfig
    let apiKey: APIKey?
    let http: HTTPClient

    /// DeepL accepts up to 50 texts and 128 KiB per request.
    static let batchLimits = (count: 50, characters: 30000)

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
        guard url(path: "translate") != nil else { return .notConfigured("Enter an https:// address for the DeepL API.") }
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

    /// Reads `/v2/usage`, which also checks the key.
    func testConnection() async throws -> String {
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        guard let url = url(path: "usage") else { throw TranslationFailure.notConfigured("Enter an https:// address for the DeepL API.") }
        let request = try HTTPClient.request(
            url,
            method: "GET",
            headers: authorization(key),
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let usage = try JSONDecoder().decode(DeepLUsage.self, from: data)
        guard let count = usage.characterCount, let limit = usage.characterLimit else { return "Connected" }
        return "Connected · \(count.formatted()) of \(limit.formatted()) characters used this period"
    }

    /// DeepL's target codes: English and Portuguese need a variant, Chinese a script.
    static func targetCode(for language: Locale.Language) -> String {
        let base = language.languageCode?.identifier.lowercased() ?? ""
        switch base {
        case "en": return language.region?.identifier == "GB" ? "EN-GB" : "EN-US"
        case "pt": return language.region?.identifier == "PT" ? "PT-PT" : "PT-BR"
        case "zh": return LanguageCatalog.isTraditionalChinese(language) ? "ZH-HANT" : "ZH-HANS"
        case "no", "nn": return "NB"
        default: return base.uppercased()
        }
    }

    /// Source codes are the bare language.
    static func sourceCode(for language: Locale.Language) -> String {
        let base = language.languageCode?.identifier.uppercased() ?? ""
        return base == "NO" || base == "NN" ? "NB" : base
    }

    func url(path: String) -> URL? {
        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            base = apiKey?.value.hasSuffix(":fx") == true ? "https://api-free.deepl.com" : config.effectiveBaseURL
        }
        return Endpoint.url(base, path: path, versionPrefix: "v2")
    }

    private func authorization(_ key: APIKey) -> [String: String] {
        ["Authorization": "DeepL-Auth-Key \(key.value)"]
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        guard let url = url(path: "translate")
        else { throw TranslationFailure.notConfigured("Enter an https:// address for the DeepL API.") }
        let batches = SegmentBatcher.batches(request.segments, maxCount: Self.batchLimits.count, maxCost: Self.batchLimits.characters)
        for batch in batches {
            try Task.checkCancellation()
            let urlRequest = try HTTPClient.request(
                url, json: body(for: batch, request: request), headers: authorization(key), custom: config.customHeaders,
                timeout: config.timeoutSeconds
            )
            let (data, _) = try await http.data(for: urlRequest, kind: config.kind)
            let translations = try JSONDecoder().decode(DeepLResponse.self, from: data).translations
            guard translations.count == batch.count else {
                throw TranslationFailure.badResponse("DeepL returned \(translations.count) translations for \(batch.count) texts.")
            }
            for (segment, translation) in zip(batch, translations) {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: translation.text)))
            }
        }
        continuation.yield(.usage(TranslationUsage(characters: request.characterCount)))
    }

    private func body(for batch: [TranslationSegment], request: TranslationRequest) -> [String: Any] {
        var body: [String: Any] = [
            "text": batch.map(\.text),
            "target_lang": Self.targetCode(for: request.target),
            "preserve_formatting": true,
        ]
        if let source = request.source {
            body["source_lang"] = Self.sourceCode(for: source)
        }
        if config.formality != .automatic {
            body["formality"] = config.formality.rawValue
        }
        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            body["model_type"] = model
        }
        return body
    }
}

private struct DeepLResponse: Decodable {
    struct Translation: Decodable {
        let text: String
    }

    let translations: [Translation]
}

private struct DeepLUsage: Decodable {
    let characterCount: Int?
    let characterLimit: Int?

    private enum CodingKeys: String, CodingKey {
        case characterCount = "character_count"
        case characterLimit = "character_limit"
    }
}
