import Foundation
import OCR

/// Google Cloud Translation (PLAN §7.7.2): Basic (v2) with an API key by default, Advanced (v3) when a glossary is
/// set. The API key goes in the `X-Goog-Api-Key` header rather than the URL, so it never appears in a URL that could
/// be logged. v3 takes no API keys: it uses an OAuth token for the service account key stored beside the API key.
/// Segments are batched.
struct GoogleTranslateProvider: TranslationProvider {
    let config: ProviderConfig
    let apiKey: APIKey?
    let http: HTTPClient
    /// For v3 (glossaries); nil until a key file is added in Settings or the bootstrap file.
    var serviceAccount: GoogleServiceAccount?
    var tokens = GoogleAccessTokens.shared

    /// v2 takes at most 128 strings per request; stay below that and below its recommended request size. v3's
    /// limits are higher, so the same batches suit both.
    static let batchLimits = (count: 100, characters: 20000)
    /// Where a glossary given by ID alone is: glossaries live in a region, and Google's examples use this one.
    static let defaultGlossaryLocation = "us-central1"

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
        guard translateURL != nil else { return .notConfigured("Enter an https:// address for the Google Translation API.") }
        if usesGlossary {
            guard serviceAccount != nil else { return .notConfigured(Self.needsServiceAccount) }
            guard glossary != nil else { return .notConfigured(Self.badGlossary) }
            return .available
        }
        guard apiKey != nil else { return .missingAPIKey }
        return .available
    }

    func translate(_ request: TranslationRequest) -> AsyncThrowingStream<TranslationEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if usesGlossary {
                        try await runWithGlossary(request, continuation: continuation)
                    } else {
                        try await run(request, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TranslationFailure.from(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async throws -> String {
        if usesGlossary {
            return try await testGlossary()
        }
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        guard let base = Endpoint.url(config.effectiveBaseURL, path: "languages", versionPrefix: "language/translate/v2"),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else {
            throw TranslationFailure.notConfigured("Enter an https:// address for the Google Translation API.")
        }
        components.queryItems = [URLQueryItem(name: "target", value: "en")]
        guard let url = components.url else { throw TranslationFailure.notConfigured("The address is not valid.") }
        let request = try HTTPClient.request(
            url, method: "GET", headers: ["X-Goog-Api-Key": key.value], custom: config.customHeaders, timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let count = try JSONDecoder().decode(GoogleLanguagesResponse.self, from: data).data.languages.count
        return "Connected · \(count) languages"
    }

    /// Google's codes: `zh-CN`/`zh-TW` for Chinese scripts, `pt-PT` for European Portuguese, else the language.
    static func code(for language: Locale.Language) -> String {
        let base = language.languageCode?.identifier.lowercased() ?? LanguageCatalog.code(for: language)
        switch base {
        case "zh": return LanguageCatalog.isTraditionalChinese(language) ? "zh-TW" : "zh-CN"
        case "pt": return language.region?.identifier == "PT" ? "pt-PT" : "pt"
        case "nb", "nn": return "no"
        default: return base
        }
    }

    /// The glossary's full resource name: as typed when it starts with `projects/`, else a glossary ID in
    /// `defaultGlossaryLocation` of `projectID`. Nil for an empty field, or an ID without a project.
    static func glossaryResource(_ text: String, projectID: String?) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("projects/") {
            return parent(ofGlossary: trimmed) == nil ? nil : trimmed
        }
        guard let projectID, !projectID.isEmpty, !trimmed.contains("/") else { return nil }
        return "projects/\(projectID)/locations/\(defaultGlossaryLocation)/glossaries/\(trimmed)"
    }

    /// `projects/…/locations/…`, where v3 requests that use the glossary go.
    static func parent(ofGlossary resource: String) -> String? {
        let parts = resource.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 6, parts[0] == "projects", parts[2] == "locations", parts[4] == "glossaries",
              !parts[1].isEmpty, !parts[3].isEmpty, !parts[5].isEmpty
        else {
            return nil
        }
        return parts[0 ..< 4].joined(separator: "/")
    }

    private static let needsServiceAccount =
        "A glossary uses Cloud Translation Advanced, which takes a service account key, not an API key. Add one, or clear the glossary."
    private static let badGlossary = "Enter the glossary as projects/…/locations/…/glossaries/…, or as its ID."

    private var usesGlossary: Bool {
        !config.glossaryResource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var glossary: String? {
        Self.glossaryResource(config.glossaryResource, projectID: serviceAccount?.projectID)
    }

    private var translateURL: URL? {
        Endpoint.url(config.effectiveBaseURL, path: "", versionPrefix: "language/translate/v2")
    }

    /// A v3 address on the endpoint's host: `/v3/<path>`.
    private func advancedURL(_ path: String) -> URL? {
        guard let base = translateURL, var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/v3/\(path)"
        components.query = nil
        return components.url
    }

    /// v3's model is a resource name; v2 names (`nmt`, `base`) mean nothing there and are left out.
    private func advancedModel(parent: String) -> String? {
        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.hasPrefix("projects/") {
            return model
        }
        return model.hasPrefix("general/") ? "\(parent)/models/\(model)" : nil
    }

    private func advancedAuthorization() async throws -> [String: String] {
        guard let serviceAccount else { throw TranslationFailure.notConfigured(Self.needsServiceAccount) }
        let token = try await tokens.token(for: serviceAccount, http: http, timeout: config.timeoutSeconds)
        return ["Authorization": "Bearer \(token)"]
    }

    /// v3 `translateText` with the glossary. A glossary needs the source language, so a request without one uses
    /// the detected language; when nothing is detected the text is translated without the glossary.
    private func runWithGlossary(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let glossary, let parent = Self.parent(ofGlossary: glossary), let url = advancedURL("\(parent):translateText") else {
            throw TranslationFailure.notConfigured(Self.badGlossary)
        }
        let headers = try await advancedAuthorization()
        let source = request.source ?? LanguageDetector.dominantLanguage(of: request.segments.map(\.text))
        let batches = SegmentBatcher.batches(request.segments, maxCount: Self.batchLimits.count, maxCost: Self.batchLimits.characters)
        for batch in batches {
            try Task.checkCancellation()
            var body: [String: Any] = [
                "contents": batch.map(\.text), "targetLanguageCode": Self.code(for: request.target), "mimeType": "text/plain",
            ]
            if let source {
                body["sourceLanguageCode"] = Self.code(for: source)
                body["glossaryConfig"] = ["glossary": glossary]
            }
            if let model = advancedModel(parent: parent) {
                body["model"] = model
            }
            let urlRequest = try HTTPClient.request(
                url,
                json: body,
                headers: headers,
                custom: config.customHeaders,
                timeout: config.timeoutSeconds
            )
            let (data, _) = try await http.data(for: urlRequest, kind: config.kind)
            let answer = try JSONDecoder().decode(GoogleAdvancedResponse.self, from: data)
            // The glossary's translations, when Google applied it; else the plain ones.
            let translations = answer.glossaryTranslations.flatMap { $0.isEmpty ? nil : $0 } ?? answer.translations ?? []
            guard translations.count == batch.count else {
                throw TranslationFailure.badResponse("Google returned \(translations.count) translations for \(batch.count) texts.")
            }
            for (segment, translation) in zip(batch, translations) {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: translation.translatedText)))
            }
        }
        continuation.yield(.usage(TranslationUsage(characters: request.characterCount)))
    }

    /// Fetches a token, then the glossary itself.
    private func testGlossary() async throws -> String {
        guard let glossary, let url = advancedURL(glossary) else { throw TranslationFailure.notConfigured(Self.badGlossary) }
        let request = try await HTTPClient.request(
            url, method: "GET", headers: advancedAuthorization(), custom: config.customHeaders, timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let entries = try JSONDecoder().decode(GoogleGlossaryResponse.self, from: data).entryCount
        return entries.map { "Connected · glossary with \($0) entries" } ?? "Connected · glossary found"
    }

    private func run(_ request: TranslationRequest, continuation: SegmentEmitter.Continuation) async throws {
        guard let url = translateURL
        else { throw TranslationFailure.notConfigured("Enter an https:// address for the Google Translation API.") }
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        let batches = SegmentBatcher.batches(request.segments, maxCount: Self.batchLimits.count, maxCost: Self.batchLimits.characters)
        for batch in batches {
            try Task.checkCancellation()
            var body: [String: Any] = ["q": batch.map(\.text), "target": Self.code(for: request.target), "format": "text"]
            if let source = request.source {
                body["source"] = Self.code(for: source)
            }
            let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty {
                body["model"] = model
            }
            let urlRequest = try HTTPClient.request(
                url, json: body, headers: ["X-Goog-Api-Key": key.value], custom: config.customHeaders, timeout: config.timeoutSeconds
            )
            let (data, _) = try await http.data(for: urlRequest, kind: config.kind)
            let translations = try JSONDecoder().decode(GoogleTranslateResponse.self, from: data).data.translations
            guard translations.count == batch.count else {
                throw TranslationFailure.badResponse("Google returned \(translations.count) translations for \(batch.count) texts.")
            }
            for (segment, translation) in zip(batch, translations) {
                continuation.yield(.segment(TranslatedSegment(id: segment.id, text: translation.translatedText)))
            }
        }
        continuation.yield(.usage(TranslationUsage(characters: request.characterCount)))
    }
}

private struct GoogleTranslateResponse: Decodable {
    struct Payload: Decodable {
        let translations: [Translation]
    }

    struct Translation: Decodable {
        let translatedText: String
    }

    let data: Payload
}

/// v3's `TranslateTextResponse`: `glossaryTranslations` is there when a glossary was applied.
private struct GoogleAdvancedResponse: Decodable {
    struct Translation: Decodable {
        let translatedText: String
    }

    let translations: [Translation]?
    let glossaryTranslations: [Translation]?
}

private struct GoogleGlossaryResponse: Decodable {
    /// A number, or a string from some API front ends.
    let entryCount: Int?

    enum CodingKeys: String, CodingKey {
        case entryCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? container.decodeIfPresent(Int.self, forKey: .entryCount) {
            entryCount = number
        } else {
            entryCount = (try? container.decodeIfPresent(String.self, forKey: .entryCount)).flatMap { $0.flatMap(Int.init) }
        }
    }
}

private struct GoogleLanguagesResponse: Decodable {
    struct Payload: Decodable {
        let languages: [Language]
    }

    struct Language: Decodable {
        let language: String
    }

    let data: Payload
}
