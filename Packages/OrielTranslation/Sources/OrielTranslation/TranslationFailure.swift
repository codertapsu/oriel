import Foundation

/// Why a translation did not happen. Provider-specific errors (HTTP statuses, `URLError`, Translation and
/// FoundationModels errors) are mapped onto these cases, so the UI and the CLI have one vocabulary.
///
/// Named `TranslationFailure` because Apple's Translation framework already has a `TranslationError`.
public enum TranslationFailure: LocalizedError, Sendable, Equatable {
    /// OCR found no text in the capture.
    case noText
    case sourceLanguageUnknown
    case packNotInstalled(source: String, target: String)
    case unsupportedLanguagePair(source: String, target: String)
    case missingAPIKey
    case notConfigured(String)
    /// The server rejected the API key (HTTP 401 or 403, or Google's "API key not valid").
    case unauthorized(String)
    /// HTTP 429. `retryAfter` is in seconds, when the server said.
    case rateLimited(retryAfter: Int?)
    /// The account's quota is used up (DeepL's HTTP 456).
    case quotaExceeded(String)
    /// Oriel's own monthly cap for the provider is reached.
    case capReached
    case offline
    case unreachable(String)
    case timedOut
    case server(status: Int, message: String)
    /// The answer could not be read.
    case badResponse(String)
    /// The model or endpoint does not exist on the server (HTTP 404), or a model refused the text.
    case modelUnavailable(String)
    case unavailable(String)
    case unknownProvider(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .noText: "No text was found in the capture."
        case .sourceLanguageUnknown: "Couldn't tell which language the text is in."
        case let .packNotInstalled(source, target):
            "The language pack for \(LanguageCatalog.name(of: source)) → \(LanguageCatalog.name(of: target)) isn't downloaded yet."
        case let .unsupportedLanguagePair(source, target):
            "\(LanguageCatalog.name(of: source)) → \(LanguageCatalog.name(of: target)) isn't supported by this provider."
        case .missingAPIKey: "This provider needs an API key. Add one in Settings → Translation."
        case let .notConfigured(detail): detail
        case let .unauthorized(message): "The provider rejected the API key: \(message)"
        case let .rateLimited(retryAfter):
            retryAfter.map { "Too many requests. Try again in \($0) s." } ?? "Too many requests. Try again shortly."
        case let .quotaExceeded(message): "The provider's quota is used up: \(message)"
        case .capReached: "The monthly usage cap for this provider is reached. Raise it in Settings → Translation."
        case .offline: "You're offline. Use Apple Translation, Apple Intelligence or a local model."
        case let .unreachable(message): "Couldn't reach the provider: \(message)"
        case .timedOut: "The provider took too long to answer."
        case let .server(status, message): "The provider failed (HTTP \(status)): \(message)"
        case let .badResponse(message): "The provider's answer couldn't be read: \(message)"
        case let .modelUnavailable(message): message
        case let .unavailable(reason): reason
        case let .unknownProvider(id): "There is no translation provider called “\(id)”."
        case .cancelled: "Cancelled."
        }
    }

    /// A 400 or 422: the server understood the request and refused it (an unsupported parameter, for example).
    var isRejectedRequest: Bool {
        if case let .server(status, _) = self {
            return status == 400 || status == 422
        }
        return false
    }

    /// Maps any error a provider throws onto a failure.
    static func from(_ error: any Error) -> TranslationFailure {
        if let failure = error as? TranslationFailure {
            return failure
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError {
            return HTTPErrorMapper.failure(for: urlError)
        }
        return .badResponse(error.localizedDescription)
    }
}
