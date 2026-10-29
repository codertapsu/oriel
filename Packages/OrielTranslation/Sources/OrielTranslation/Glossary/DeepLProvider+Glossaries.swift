import Foundation

/// DeepL's glossary API (v2): `GET /v2/glossary-language-pairs`, `POST /v2/glossaries` with TSV entries, and
/// `DELETE /v2/glossaries/{id}`. A v2 glossary cannot be edited, so a changed glossary is a new one.
extension DeepLProvider: DeepLGlossaryClient {
    func glossaryLanguagePairs() async throws -> Set<String> {
        let (key, url) = try glossaryEndpoint("glossary-language-pairs")
        let request = try HTTPClient.request(
            url,
            method: "GET",
            headers: authorization(key),
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let pairs = try JSONDecoder().decode(DeepLGlossaryPairs.self, from: data).supportedLanguages
        return Set(pairs.map { "\($0.sourceLang.lowercased())>\($0.targetLang.lowercased())" })
    }

    func createGlossary(_ spec: DeepLGlossarySpec) async throws -> String {
        let (key, url) = try glossaryEndpoint("glossaries")
        let body: [String: Any] = [
            "name": spec.name,
            "source_lang": spec.source,
            "target_lang": spec.target,
            "entries": spec.entries,
            "entries_format": "tsv",
        ]
        let request = try HTTPClient.request(
            url,
            json: body,
            headers: authorization(key),
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        let (data, _) = try await http.data(for: request, kind: config.kind)
        let created = try JSONDecoder().decode(DeepLGlossaryCreated.self, from: data)
        guard !created.glossaryID.isEmpty else { throw TranslationFailure.badResponse("DeepL created a glossary without an id.") }
        return created.glossaryID
    }

    func deleteGlossary(_ id: String) async throws {
        let (key, url) = try glossaryEndpoint("glossaries/\(id)")
        let request = try HTTPClient.request(
            url,
            method: "DELETE",
            headers: authorization(key),
            custom: config.customHeaders,
            timeout: config.timeoutSeconds
        )
        _ = try await http.data(for: request, kind: config.kind)
    }

    private func glossaryEndpoint(_ path: String) throws -> (APIKey, URL) {
        guard let key = apiKey else { throw TranslationFailure.missingAPIKey }
        guard let url = url(path: path) else { throw TranslationFailure.notConfigured("Enter an https:// address for the DeepL API.") }
        return (key, url)
    }
}

/// `{"supported_languages": [{"source_lang": "de", "target_lang": "en"}, …]}`
private struct DeepLGlossaryPairs: Decodable {
    struct Pair: Decodable {
        let sourceLang: String
        let targetLang: String

        private enum CodingKeys: String, CodingKey {
            case sourceLang = "source_lang"
            case targetLang = "target_lang"
        }
    }

    let supportedLanguages: [Pair]

    private enum CodingKeys: String, CodingKey {
        case supportedLanguages = "supported_languages"
    }
}

/// `{"glossary_id": "def3a26b-…", "ready": true, "entry_count": 2, …}`
private struct DeepLGlossaryCreated: Decodable {
    let glossaryID: String

    private enum CodingKeys: String, CodingKey {
        case glossaryID = "glossary_id"
    }
}
