import Foundation
import Testing
@testable import Upload

struct OAuthTests {
    private let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

    private func query(_ url: URL) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { (
            $0.name,
            $0.value ?? ""
        ) })
    }

    @Test func dropboxAsksForACodeWithPKCEAndARefreshToken() throws {
        let provider = try OAuthProvider.dropbox(DropboxConfiguration(appKey: " abc123xyz "), endpoints: .production)
        let url = try provider.authorizationURL(pkce: pkce, state: "s1")
        #expect(url.absoluteString.hasPrefix("https://www.dropbox.com/oauth2/authorize?"))
        let items = query(url)
        #expect(items["client_id"] == "abc123xyz")
        #expect(items["response_type"] == "code")
        #expect(items["code_challenge"] == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["token_access_type"] == "offline")
        #expect(items["redirect_uri"] == "db-abc123xyz://2/token")
        #expect(items["state"] == "s1")
        // Dropbox grants what the app's Permissions tab says.
        #expect(items["scope"] == nil)
        #expect(provider.callbackScheme == "db-abc123xyz")
        #expect(provider.tokenURL.absoluteString == "https://api.dropboxapi.com/oauth2/token")
    }

    @Test func googleUsesTheReversedClientIDAndTheDriveFileScope() throws {
        let configuration = GoogleDriveConfiguration(clientID: "1234-abcd.apps.googleusercontent.com")
        let provider = try OAuthProvider.googleDrive(configuration, endpoints: .production)
        let items = try query(provider.authorizationURL(pkce: pkce, state: "s2"))
        #expect(items["redirect_uri"] == "com.googleusercontent.apps.1234-abcd:/oauth2redirect")
        #expect(items["scope"] == "https://www.googleapis.com/auth/drive.file")
        #expect(items["access_type"] == "offline")
        #expect(items["prompt"] == "select_account consent")
        #expect(items["code_challenge_method"] == "S256")
        #expect(provider.callbackScheme == "com.googleusercontent.apps.1234-abcd")

        var everything = configuration
        everything.access = .everything
        let full = try OAuthProvider.googleDrive(everything, endpoints: .production)
        #expect(try query(full.authorizationURL(pkce: pkce, state: "s"))["scope"] == "https://www.googleapis.com/auth/drive")
    }

    @Test func theCodeAndTheRefreshTokenGoInAFormWithTheVerifier() throws {
        let provider = try OAuthProvider.dropbox(DropboxConfiguration(appKey: "key"), endpoints: .production)
        let exchange = provider.codeExchangeRequest(code: "c+o/d=e", pkce: pkce)
        #expect(exchange.httpMethod == "POST")
        #expect(exchange.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let fields = FormEncoding.decode(exchange.httpBody ?? Data())
        #expect(fields == [
            "grant_type": "authorization_code", "code": "c+o/d=e", "code_verifier": pkce.verifier, "client_id": "key",
            "redirect_uri": "db-key://2/token",
        ])
        #expect((exchange.httpBody ?? Data()).utf8Text.contains("code=c%2Bo%2Fd%3De"))
        let refresh = FormEncoding.decode(provider.refreshRequest(refreshToken: "r1").httpBody ?? Data())
        #expect(refresh == ["grant_type": "refresh_token", "refresh_token": "r1", "client_id": "key"])
    }

    @Test func theCallbackGivesTheCodeOnlyForThisSignIn() throws {
        let url = try #require(URL(string: "db-key://2/token?code=abc123&state=s1"))
        #expect(try OAuthCallback.code(from: url, expectedState: "s1", service: "Dropbox") == "abc123")
        let google =
            try #require(
                URL(
                    string: "com.googleusercontent.apps.1-a:/oauth2redirect?state=s2&code=4/0Ab"
                        + "&scope=https://www.googleapis.com/auth/drive.file"
                )
            )
        #expect(try OAuthCallback.code(from: google, expectedState: "s2", service: "Google Drive") == "4/0Ab")
        #expect(throws: UploadError.self) { try OAuthCallback.code(from: url, expectedState: "other", service: "Dropbox") }
        let noCode = try #require(URL(string: "db-key://2/token?state=s1"))
        #expect(throws: UploadError.failed("Dropbox did not send a sign-in code. Try again.")) {
            try OAuthCallback.code(from: noCode, expectedState: "s1", service: "Dropbox")
        }
    }

    @Test func aRefusalSaysSo() throws {
        let denied =
            try #require(
                URL(string: "db-key://2/token?error=access_denied&error_description=The+user+chose+not+to+give+your+app+access&state=s1")
            )
        #expect(throws: UploadError.forbidden("Oriel wasn't allowed into your Dropbox, so it can't upload there.")) {
            try OAuthCallback.code(from: denied, expectedState: "s1", service: "Dropbox")
        }
        let other = try #require(URL(string: "db-key://2/token?error=invalid_scope&error_description=Bad+scope"))
        #expect(throws: UploadError.failed("Dropbox refused the sign-in: Bad scope")) {
            try OAuthCallback.code(from: other, expectedState: "s1", service: "Dropbox")
        }
    }

    @Test func tokenAnswersParseAndErrorsMeanSomething() throws {
        let dropbox = #"""
        {"access_token": "sl.A", "token_type": "bearer", "expires_in": 14400, "refresh_token": "R",
         "scope": "files.content.write sharing.write", "uid": "1", "account_id": "dbid:x"}
        """#
        let parsed = try OAuthTokenResponse.parse(Data(dropbox.utf8), status: 200, service: "Dropbox")
        #expect(parsed == OAuthTokenResponse(
            accessToken: "sl.A",
            refreshToken: "R",
            expiresIn: 14400,
            scope: "files.content.write sharing.write"
        ))
        let now = Date(timeIntervalSince1970: 1000)
        #expect(parsed.tokens(now: now).expiresAt == Date(timeIntervalSince1970: 15400))

        let grant = #"{"error":"invalid_grant","error_description":"refresh token is invalid or revoked"}"#
        #expect(throws: UploadError.signInRequired(service: "Dropbox")) {
            try OAuthTokenResponse.parse(Data(grant.utf8), status: 400, service: "Dropbox")
        }
        let client = #"{"error":"invalid_client","error_description":"The OAuth client was not found."}"#
        #expect(throws: UploadError.invalidSettings("Google Drive doesn't recognize this app. Check the client ID.")) {
            try OAuthTokenResponse.parse(Data(client.utf8), status: 401, service: "Google Drive")
        }
        #expect(throws: UploadError.server(status: 503, message: "")) {
            try OAuthTokenResponse.parse(Data("<html>".utf8), status: 503, service: "Dropbox")
        }
    }

    @Test func aRefreshKeepsTheRefreshTokenAccountAndClient() {
        let tokens = OAuthTokens(
            accessToken: "old",
            refreshToken: "R",
            expiresAt: nil,
            scope: "a b",
            account: "me@example.com",
            clientID: "key"
        )
        let now = Date(timeIntervalSince1970: 0)
        let fresh = tokens.refreshed(with: OAuthTokenResponse(accessToken: "new", refreshToken: nil, expiresIn: 3600, scope: nil), now: now)
        #expect(fresh == OAuthTokens(
            accessToken: "new", refreshToken: "R", expiresAt: Date(timeIntervalSince1970: 3600), scope: "a b", account: "me@example.com",
            clientID: "key"
        ))
        let rotated = tokens.refreshed(
            with: OAuthTokenResponse(accessToken: "new", refreshToken: "R2", expiresIn: nil, scope: "c"),
            now: now
        )
        #expect(rotated.refreshToken == "R2")
        #expect(rotated.scope == "c")
    }

    @Test func tokensExpireTwoMinutesEarly() {
        let tokens = OAuthTokens(accessToken: "a", expiresAt: Date(timeIntervalSince1970: 1000))
        #expect(!tokens.isExpired(at: Date(timeIntervalSince1970: 879)))
        #expect(tokens.isExpired(at: Date(timeIntervalSince1970: 880)))
        #expect(!OAuthTokens(accessToken: "a").isExpired(at: .distantFuture))
        #expect(tokens.grants("anything"))
        #expect(OAuthTokens(accessToken: "a", scope: "x y").grants("y"))
        #expect(!OAuthTokens(accessToken: "a", scope: "x y").grants("z"))
        #expect(OAuthTokens(accessToken: "a", clientID: "k").belongs(to: "k"))
        #expect(!OAuthTokens(accessToken: "a", clientID: "k").belongs(to: "other"))
    }

    @Test func clientIDsAndAppKeysAreChecked() {
        #expect(GoogleDriveConfiguration(clientID: "1-a.apps.googleusercontent.com").problem == nil)
        #expect(GoogleDriveConfiguration(clientID: "GOCSPX-secret").problem != nil)
        #expect(DropboxConfiguration(appKey: "abc123").problem == nil)
        #expect(DropboxConfiguration(appKey: "https://www.dropbox.com").problem != nil)
        #expect(DropboxConfiguration().missingField == "an app key")
    }
}
