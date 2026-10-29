import Foundation

/// A destination's OAuth tokens, kept as JSON in the Keychain (`UploadSecret.oauthTokens`), never in settings or logs.
public nonisolated struct OAuthTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    /// Long-lived; Dropbox sends one for `token_access_type=offline`, Google for installed apps.
    public var refreshToken: String?
    /// When the access token stops working; nil when the service did not say.
    public var expiresAt: Date?
    /// The scopes granted, space-separated.
    public var scope: String?
    /// Who signed in ("marcus@example.com"), for Settings.
    public var account: String?
    /// The app key or client ID the tokens belong to; after the user types another one, they need a new sign-in.
    public var clientID: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        scope: String? = nil,
        account: String? = nil,
        clientID: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scope = scope
        self.account = account
        self.clientID = clientID
    }

    /// Whether the tokens came from `clientID`, the app key or client ID now in Settings.
    public func belongs(to clientID: String) -> Bool {
        self.clientID == nil || self.clientID == clientID
    }

    /// Two minutes early, so a token never runs out in the middle of an upload's first request.
    public static let leeway: TimeInterval = 120

    public func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now.addingTimeInterval(Self.leeway) >= expiresAt
    }

    /// Whether `scope` names `required` (scopes are space-separated).
    public func grants(_ required: String) -> Bool {
        guard let scope else { return true }
        return scope.split(separator: " ").contains { $0 == required }
    }

    /// These tokens after a refresh: a new access token and expiry, the same refresh token unless the service sent a
    /// new one, and the same account.
    func refreshed(with response: OAuthTokenResponse, now: Date) -> OAuthTokens {
        OAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: response.expiresIn.map { now.addingTimeInterval($0) },
            scope: response.scope ?? scope,
            account: account,
            clientID: clientID
        )
    }
}
