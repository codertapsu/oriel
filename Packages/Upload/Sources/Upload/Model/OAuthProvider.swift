import Foundation

/// The OAuth 2 details of one signed-in service, built from the destination's settings: the authorization page, the
/// token endpoint and the redirect. Requests are built here and sent by `UploadService`, so they are tested as data.
///
/// Both services take a public client with PKCE and no secret: Dropbox with `token_access_type=offline` for a refresh
/// token, Google with an iOS-type client, whose refresh token comes with every installed-app sign-in.
nonisolated struct OAuthProvider: Sendable, Equatable {
    /// "Dropbox", "Google Drive", for messages.
    let service: String
    let clientID: String
    let authorizeURL: String
    let tokenURL: URL
    let redirectURI: String
    let callbackScheme: String
    /// Asked for at sign-in; nil lets the service grant what the app is configured with (Dropbox's App Console).
    let scope: String?
    let extraParameters: [URLQueryItem]

    static func dropbox(_ configuration: DropboxConfiguration, endpoints: UploadEndpoints) throws -> OAuthProvider {
        try OAuthProvider(
            service: "Dropbox",
            clientID: configuration.trimmedAppKey,
            authorizeURL: endpoints.dropboxAuthorize,
            tokenURL: UploadEndpoints.url(endpoints.dropboxAPI, "/oauth2/token"),
            redirectURI: configuration.redirectURI,
            callbackScheme: configuration.callbackScheme,
            scope: nil,
            extraParameters: [URLQueryItem(name: "token_access_type", value: "offline")]
        )
    }

    static func googleDrive(_ configuration: GoogleDriveConfiguration, endpoints: UploadEndpoints) throws -> OAuthProvider {
        try OAuthProvider(
            service: "Google Drive",
            clientID: configuration.trimmedClientID,
            authorizeURL: endpoints.googleAuthorize,
            tokenURL: UploadEndpoints.url(endpoints.googleToken),
            redirectURI: configuration.redirectURI,
            callbackScheme: configuration.callbackScheme,
            scope: configuration.access.scope,
            // `consent` makes Google send a refresh token on every sign-in, not only on the first one.
            extraParameters: [
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "select_account consent"),
            ]
        )
    }

    /// The page the sign-in sheet opens.
    func authorizationURL(pkce: PKCE, state: String) throws -> URL {
        var query = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: PKCE.method),
            URLQueryItem(name: "state", value: state),
        ]
        if let scope {
            query.append(URLQueryItem(name: "scope", value: scope))
        }
        return try UploadEndpoints.url(authorizeURL, query: query + extraParameters)
    }

    /// Trades the code from the redirect, with the verifier, for tokens.
    func codeExchangeRequest(code: String, pkce: PKCE) -> URLRequest {
        formRequest([
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: pkce.verifier),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ])
    }

    /// A new access token for a refresh token.
    func refreshRequest(refreshToken: String) -> URLRequest {
        formRequest([
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID),
        ])
    }

    private func formRequest(_ items: [URLQueryItem]) -> URLRequest {
        var request = URLRequest(url: tokenURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = FormEncoding.body(items)
        return request
    }
}
