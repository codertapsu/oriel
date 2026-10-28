import Foundation

/// Maps HTTP statuses, error bodies and `URLError`s onto `TranslationFailure`s, the same way for every provider.
enum HTTPErrorMapper {
    static func failure(status: Int, body: Data, response: HTTPURLResponse?, kind: ProviderKind) -> TranslationFailure {
        let serverMessage = message(in: body)
        let message = serverMessage ?? HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        switch status {
        case 400 where kind == .google && message.localizedCaseInsensitiveContains("API key"):
            return .unauthorized(message)
        case 401, 403:
            return .unauthorized(message)
        case 404:
            return .modelUnavailable("Not found on the server: \(message)")
        case 408, 504:
            return .timedOut
        case 413:
            return .badResponse(serverMessage.map { "The request is too large: \($0)" } ?? "The request is too large for the provider.")
        case 429:
            let retryAfter = response?.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return .rateLimited(retryAfter: retryAfter)
        case 456 where kind == .deepl:
            return .quotaExceeded(message)
        default:
            return .server(status: status, message: message)
        }
    }

    /// The human-readable message of an error body: `{"error": {"message": …}}` (OpenAI, Ollama, Anthropic, Google),
    /// `{"error": "…"}` (llama.cpp, Ollama's native API) or `{"message": "…"}` (DeepL). Falls back to a short plain-text
    /// body.
    static func message(in body: Data) -> String? {
        if let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
        }
        let text = UTF8Text.decode(body.prefix(300)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.hasPrefix("<") else { return nil }
        return text
    }

    static func failure(for error: URLError) -> TranslationFailure {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            .offline
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            .unreachable("Nothing answers at that address. Is the server running?")
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired:
            .unreachable("The secure connection failed: \(error.localizedDescription)")
        case .appTransportSecurityRequiresSecureConnection:
            .notConfigured("Plain HTTP is only allowed for local servers. Use an https:// address.")
        default:
            .unreachable(error.localizedDescription)
        }
    }
}
