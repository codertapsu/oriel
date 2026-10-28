import Foundation

/// OAuth access tokens for Google service accounts (PLAN §7.7.2): a JWT signed with the account's key (RS256) is
/// exchanged at the account's token URL (Google's server-to-server OAuth, RFC 7523), and the token is reused until a
/// minute before it expires. One instance is shared, because provider values are rebuilt for every translation.
actor GoogleAccessTokens {
    static let shared = GoogleAccessTokens()
    /// Cloud Translation only.
    static let scope = "https://www.googleapis.com/auth/cloud-translation"
    /// How long a token Oriel asks for may live: Google's maximum.
    static let lifetime: TimeInterval = 3600

    private var tokens: [String: (value: String, expires: Date)] = [:]
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    /// A token for `account`, from the cache while it has more than a minute left, else a new one.
    func token(for account: GoogleServiceAccount, http: HTTPClient, timeout: TimeInterval) async throws -> String {
        let key = "\(account.clientEmail) \(account.tokenURL.absoluteString)"
        if let cached = tokens[key], cached.expires.timeIntervalSince(now()) > 60 {
            return cached.value
        }
        let issued = now()
        var request = URLRequest(url: account.tokenURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: max(1, timeout))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.formBody([
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": Self.assertion(for: account, issuedAt: issued),
        ])
        let (data, response) = try await http.session.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw TranslationFailure.badResponse("Google's token service did not answer over HTTP.")
        }
        guard (200 ..< 300).contains(status) else { throw Self.failure(status: status, body: data) }
        guard let answer = try? JSONDecoder().decode(TokenAnswer.self, from: data), !answer.accessToken.isEmpty else {
            throw TranslationFailure.badResponse("Google's token service sent no access token.")
        }
        tokens[key] = (answer.accessToken, issued.addingTimeInterval(answer.expiresIn ?? Self.lifetime))
        return answer.accessToken
    }

    /// The signed JWT, `header.claims.signature`, each part base64url without padding.
    static func assertion(for account: GoogleServiceAccount, issuedAt: Date) throws -> String {
        let issued = Int(issuedAt.timeIntervalSince1970)
        let header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        let claims: [String: Any] = [
            "iss": account.clientEmail,
            "scope": scope,
            "aud": account.tokenURL.absoluteString,
            "iat": issued,
            "exp": issued + Int(lifetime),
        ]
        let options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        let signingInput = try [header, claims]
            .map { try base64URL(JSONSerialization.data(withJSONObject: $0, options: options)) }
            .joined(separator: ".")
        return try "\(signingInput).\(base64URL(account.sign(Data(signingInput.utf8))))"
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// `application/x-www-form-urlencoded`, with everything but unreserved characters percent-encoded.
    static func formBody(_ fields: [String: String]) throws -> Data {
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let pairs = try fields.sorted { $0.key < $1.key }.map { name, value in
            guard let name = name.addingPercentEncoding(withAllowedCharacters: unreserved),
                  let value = value.addingPercentEncoding(withAllowedCharacters: unreserved)
            else {
                throw TranslationFailure.badResponse("A token request field could not be encoded.")
            }
            return "\(name)=\(value)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// Google's OAuth errors are `{"error": "invalid_grant", "error_description": "Invalid JWT Signature."}`.
    static func failure(status: Int, body: Data) -> TranslationFailure {
        let answer = try? JSONDecoder().decode(TokenError.self, from: body)
        let message = answer?.description ?? answer?.error ?? HTTPErrorMapper.message(in: body) ?? "HTTP \(status)"
        switch status {
        case 400, 401, 403: return .unauthorized("Google refused the service account key: \(message)")
        case 429: return .rateLimited(retryAfter: nil)
        default: return .server(status: status, message: message)
        }
    }
}

private struct TokenAnswer: Decodable {
    let accessToken: String
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

private struct TokenError: Decodable {
    let error: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case error
        case description = "error_description"
    }
}
