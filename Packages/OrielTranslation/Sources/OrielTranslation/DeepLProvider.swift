import Foundation
import OCR
import OrielCore

/// DeepL's `/v2/translate` (PLAN §7.7.2), with `Authorization: DeepL-Auth-Key …`, batched texts and the formality
/// option. Free-plan keys (ending in `:fx`) use `api-free.deepl.com` unless an endpoint is configured.
///
/// Glossary projects (PLAN §17) use DeepL's glossaries: `DeepLGlossaryBook` creates one per project and language
/// pair the first time it is needed and again when its terms change, and translations send its `glossary_id` with
/// the source language, which DeepL requires with a glossary. For pairs DeepL glossaries do not support, or when the
/// glossary cannot be made, the terms are protected with placeholder tokens instead.
struct DeepLProvider: TranslationProvider {
    let config: ProviderConfig
    let apiKey: APIKey?
    let http: HTTPClient
    /// Where glossary ids are kept; nil never creates glossaries, and glossary terms are protected with tokens.
    var glossaries: DeepLGlossaryBook?

    private static let log = Log.logger("translation")

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

    func authorization(_ key: APIKey) -> [String: String] {
        ["Authorization": "DeepL-Auth-Key \(key.value)"]
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        guard let url = url(path: "translate")
        else { throw TranslationFailure.notConfigured("Enter an https:// address for the DeepL API.") }
        let send = Sender(provider: self, request: request, key: key, url: url) { continuation.yield(.segment($0)) }
        let glossary = request.glossary
        guard !glossary.isEmpty else {
            let characters = try await send(request.segments, source: request.source, glossaryID: nil)
            continuation.yield(.usage(TranslationUsage(characters: characters)))
            return
        }
        // A glossary needs the source language, so text without one uses the detected language.
        let source = request.source ?? LanguageDetector.dominantLanguage(of: request.segments.map(\.text))
        if let characters = try await translateWithGlossary(request, source: source, send: send) {
            continuation.yield(.usage(TranslationUsage(characters: characters)))
            return
        }
        var characters = 0
        try await GlossaryProtection.run(
            request.segments,
            terms: glossary.usableTerms,
            emit: send.emit,
            translate: { segments, emit in
                characters += try await send(segments, source: source, glossaryID: nil, emit: emit)
            }
        )
        continuation.yield(.usage(TranslationUsage(characters: characters)))
    }

    /// Translates with the DeepL glossary for the request's project and pair, and returns the characters sent; nil
    /// when there is no glossary to use (no source language, no usable term, a pair DeepL glossaries do not cover),
    /// so the caller protects the terms itself. A glossary DeepL no longer knows (deleted in the account, or made with
    /// another account's key) is made again, once.
    private func translateWithGlossary(_ request: TranslationRequest, source: Locale.Language?, send: Sender) async throws -> Int? {
        guard let source,
              let spec = DeepLGlossarySpec(glossary: request.glossary, providerID: config.id, source: source, target: request.target),
              let current = await glossaryID(for: spec)
        else { return nil }
        do {
            return try await send(request.segments, source: source, glossaryID: current)
        } catch let failure as TranslationFailure where Self.isMissingGlossary(failure) {
            Self.log.info("DeepL no longer knows a glossary of \(config.id.rawValue, privacy: .public); creating it again")
            await glossaries?.forget(spec.key)
            guard let fresh = await glossaryID(for: spec) else { return nil }
            return try await send(request.segments, source: source, glossaryID: fresh)
        }
    }

    /// The DeepL glossary for `spec`, created when needed; nil when DeepL has none for the pair or refused to make it.
    private func glossaryID(for spec: DeepLGlossarySpec) async -> String? {
        guard let glossaries else { return nil }
        do {
            return try await glossaries.glossaryID(for: spec, client: self)
        } catch {
            let reason = TranslationFailure.from(error).localizedDescription
            Self.log.error("Couldn't create a DeepL glossary, so its terms are protected instead: \(reason, privacy: .public)")
            return nil
        }
    }

    /// A translation refused because the glossary id is unknown: 404, or 400 naming the glossary.
    static func isMissingGlossary(_ failure: TranslationFailure) -> Bool {
        switch failure {
        case .modelUnavailable: true
        case let .server(status, message): (status == 400 || status == 404) && message.localizedCaseInsensitiveContains("glossary")
        default: false
        }
    }

    /// Sends segments to `/v2/translate` in batches, emitting each translation, and returns the characters sent.
    private struct Sender {
        let provider: DeepLProvider
        let request: TranslationRequest
        let key: APIKey
        let url: URL
        let emit: (TranslatedSegment) -> Void

        func callAsFunction(_ segments: [TranslationSegment], source: Locale.Language?, glossaryID: String?) async throws -> Int {
            try await callAsFunction(segments, source: source, glossaryID: glossaryID, emit: emit)
        }

        func callAsFunction(
            _ segments: [TranslationSegment],
            source: Locale.Language?,
            glossaryID: String?,
            emit: (TranslatedSegment) -> Void
        ) async throws -> Int {
            let limits = DeepLProvider.batchLimits
            for batch in SegmentBatcher.batches(segments, maxCount: limits.count, maxCost: limits.characters) {
                try Task.checkCancellation()
                let body = provider.body(for: batch, request: request, source: source, glossaryID: glossaryID)
                let urlRequest = try HTTPClient.request(
                    url, json: body, headers: provider.authorization(key), custom: provider.config.customHeaders,
                    timeout: provider.config.timeoutSeconds
                )
                let (data, _) = try await provider.http.data(for: urlRequest, kind: provider.config.kind)
                let translations = try JSONDecoder().decode(DeepLResponse.self, from: data).translations
                guard translations.count == batch.count else {
                    throw TranslationFailure.badResponse("DeepL returned \(translations.count) translations for \(batch.count) texts.")
                }
                for (segment, translation) in zip(batch, translations) {
                    emit(TranslatedSegment(id: segment.id, text: translation.text))
                }
            }
            return segments.reduce(0) { $0 + $1.text.count }
        }
    }

    private func body(
        for batch: [TranslationSegment],
        request: TranslationRequest,
        source: Locale.Language?,
        glossaryID: String?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "text": batch.map(\.text),
            "target_lang": Self.targetCode(for: request.target),
            "preserve_formatting": true,
        ]
        if let source {
            body["source_lang"] = Self.sourceCode(for: source)
        }
        if let glossaryID {
            body["glossary_id"] = glossaryID
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
