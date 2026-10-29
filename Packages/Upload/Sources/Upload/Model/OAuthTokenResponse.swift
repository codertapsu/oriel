import Foundation

/// A token endpoint's answer (RFC 6749 §5.1), the same shape at Dropbox and Google, and the errors it can carry (§5.2).
nonisolated struct OAuthTokenResponse: Sendable, Equatable {
    var accessToken: String
    var refreshToken: String?
    /// Seconds.
    var expiresIn: TimeInterval?
    var scope: String?

    /// The tokens a sign-in starts with.
    func tokens(now: Date) -> OAuthTokens {
        OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresIn.map { now.addingTimeInterval($0) },
            scope: scope
        )
    }

    /// Parses a token endpoint's body. `invalid_grant` means the code or refresh token is no good any more, so the user
    /// must sign in again; `invalid_client` means the app key or client ID is wrong.
    static func parse(_ data: Data, status: Int, service: String) throws -> OAuthTokenResponse {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if (200 ..< 300).contains(status), let accessToken = object["access_token"] as? String, !accessToken.isEmpty {
            let expiresIn = (object["expires_in"] as? NSNumber)?.doubleValue ?? (object["expires_in"] as? String).flatMap(Double.init)
            return OAuthTokenResponse(
                accessToken: accessToken,
                refreshToken: (object["refresh_token"] as? String).flatMap { $0.isEmpty ? nil : $0 },
                expiresIn: expiresIn,
                scope: object["scope"] as? String
            )
        }
        let code = object["error"] as? String ?? ""
        let description = object["error_description"] as? String ?? ""
        switch code {
        case "invalid_grant":
            throw UploadError.signInRequired(service: service)
        case "invalid_client", "unauthorized_client":
            let client = service == "Dropbox" ? "app key" : "client ID"
            throw UploadError.invalidSettings("\(service) doesn't recognize this app. Check the \(client).")
        case "" where status >= 500:
            throw UploadError.server(status: status, message: "")
        case "":
            throw UploadError.failed("\(service) sent an answer Oriel can't read.")
        default:
            let detail = description.isEmpty ? code : description
            throw UploadError.failed("\(service) refused the sign-in: \(detail)")
        }
    }
}
