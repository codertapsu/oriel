import Foundation

/// The user's settings for one provider (PLAN §7.7.5), stored in `SettingsStore`. The API key is not here: it lives
/// in the Keychain under `provider.<id>`.
struct ProviderConfig: Codable, Sendable, Hashable, Identifiable {
    /// DeepL's `formality` option.
    enum Formality: String, Codable, Sendable, CaseIterable {
        case automatic = "default"
        case more = "prefer_more"
        case less = "prefer_less"
    }

    var id: ProviderID
    var kind: ProviderKind
    var displayName: String
    var isEnabled: Bool
    /// Empty means the kind's default endpoint (OpenAI-compatible servers have none and need one).
    var baseURL: String
    /// Empty means none chosen. OpenAI-compatible and Anthropic need one; DeepL sends it as `model_type` and
    /// Google as `model` when set. Never defaulted in code (PLAN §7.7.2).
    var model: String
    /// Nil means the server's default, and the parameter is not sent (some models reject it).
    var temperature: Double?
    var timeoutSeconds: Double
    /// Sent with every request, after Oriel's own headers, so they can override them (proxies, API versions).
    var customHeaders: [String: String]
    var formality: Formality
    /// OpenAI-compatible only: ask for a JSON schema (`response_format`). Retried without it when a server refuses.
    var usesStructuredOutput: Bool
    /// Anthropic only: the required `max_tokens`.
    var maxOutputTokens: Int
    /// Characters per calendar month for Google and DeepL, tokens for LLMs. Nil means no cap.
    var monthlyCap: Int?
    /// Google only: a Cloud Translation glossary (`projects/…/locations/…/glossaries/…`, or its ID in us-central1 of
    /// the service account's project). Set, requests go to v3 with the service account key. Empty means none.
    var glossaryResource: String

    init(
        id: ProviderID,
        kind: ProviderKind,
        displayName: String? = nil,
        isEnabled: Bool = true,
        baseURL: String = "",
        model: String = "",
        temperature: Double? = nil,
        timeoutSeconds: Double = 60,
        customHeaders: [String: String] = [:],
        formality: Formality = .automatic,
        usesStructuredOutput: Bool = true,
        maxOutputTokens: Int = 4096,
        monthlyCap: Int? = nil,
        glossaryResource: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName ?? kind.displayName
        self.isEnabled = isEnabled
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.customHeaders = customHeaders
        self.formality = formality
        self.usesStructuredOutput = usesStructuredOutput
        self.maxOutputTokens = maxOutputTokens
        self.monthlyCap = monthlyCap
        self.glossaryResource = glossaryResource
    }

    /// The providers every installation has. Others come from Settings or the bootstrap file.
    static let builtIns = [
        ProviderConfig(id: .apple, kind: .apple),
        ProviderConfig(id: .foundationModels, kind: .foundationModels),
    ]

    var isBuiltIn: Bool {
        Self.builtIns.contains { $0.id == id }
    }

    /// The endpoint to use: the configured one, else the kind's default.
    var effectiveBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.defaultBaseURL ?? "" : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, displayName, isEnabled, baseURL, model, temperature, timeoutSeconds, customHeaders
        case formality, usesStructuredOutput, maxOutputTokens, monthlyCap, glossaryResource
    }

    /// Decodes leniently: fields added in later versions take their defaults, so an update never loses the user's
    /// providers (SettingsStore falls back to the default list when decoding fails).
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ProviderKind.self, forKey: .kind)
        try self.init(
            id: container.decode(ProviderID.self, forKey: .id),
            kind: kind,
            displayName: container.decodeIfPresent(String.self, forKey: .displayName),
            isEnabled: container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            baseURL: container.decodeIfPresent(String.self, forKey: .baseURL) ?? "",
            model: container.decodeIfPresent(String.self, forKey: .model) ?? "",
            temperature: container.decodeIfPresent(Double.self, forKey: .temperature),
            timeoutSeconds: container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 60,
            customHeaders: container.decodeIfPresent([String: String].self, forKey: .customHeaders) ?? [:],
            formality: container.decodeIfPresent(Formality.self, forKey: .formality) ?? .automatic,
            usesStructuredOutput: container.decodeIfPresent(Bool.self, forKey: .usesStructuredOutput) ?? true,
            maxOutputTokens: container.decodeIfPresent(Int.self, forKey: .maxOutputTokens) ?? 4096,
            monthlyCap: container.decodeIfPresent(Int.self, forKey: .monthlyCap),
            glossaryResource: container.decodeIfPresent(String.self, forKey: .glossaryResource) ?? ""
        )
    }
}
