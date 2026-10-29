import Foundation
import Testing
@testable import Upload

struct TokenRefreshTests {
    private let destination = UploadDestination(name: "Dropbox", target: .dropbox(DropboxConfiguration(appKey: "key")))

    private func service(_ server: StubServer, _ secrets: InMemorySecrets) -> UploadService {
        UploadService(
            secrets: secrets, runner: FakeProcessRunner(ProcessResult(status: 0)), endpoints: server.endpoints,
            makeSession: { StubURLProtocol.makeSession() }
        )
    }

    private func provider(_ server: StubServer) throws -> OAuthProvider {
        try OAuthProvider.dropbox(DropboxConfiguration(appKey: "key"), endpoints: server.endpoints)
    }

    @Test func anExpiredTokenIsRefreshedOnceEvenWhenAskedForTwice() async throws {
        let server = StubServer { request in
            request.url.path == "/oauth2/token" ? .json(#"{"access_token":"fresh","expires_in":14400,"token_type":"bearer"}"#) : .empty(404)
        }
        let secrets = InMemorySecrets()
        try secrets.setTokens(
            OAuthTokens(
                accessToken: "stale",
                refreshToken: "R",
                expiresAt: Date(timeIntervalSinceNow: -60),
                account: "me",
                clientID: "key"
            ),
            for: destination.id
        )
        let service = service(server, secrets)
        let provider = try provider(server)
        let http = server.http
        async let first = service.accessToken(for: destination.id, provider: provider, http: http, refresh: false)
        async let second = service.accessToken(for: destination.id, provider: provider, http: http, refresh: false)
        #expect(try await [first, second] == ["fresh", "fresh"])
        let refreshes = server.requests(to: "/oauth2/token")
        #expect(refreshes.count == 1)
        #expect(FormEncoding.decode(refreshes[0].body) == ["grant_type": "refresh_token", "refresh_token": "R", "client_id": "key"])
        let kept = try #require(try secrets.tokens(for: destination.id))
        #expect(kept.accessToken == "fresh")
        #expect(kept.refreshToken == "R")
        #expect(kept.account == "me")
        #expect(try #require(kept.expiresAt) > Date(timeIntervalSinceNow: 14000))
    }

    @Test func aValidTokenIsUsedAsItIs() async throws {
        let server = StubServer { _ in .empty(500) }
        let secrets = InMemorySecrets()
        try secrets.setTokens(
            OAuthTokens(accessToken: "good", refreshToken: "R", expiresAt: Date(timeIntervalSinceNow: 3600)),
            for: destination.id
        )
        let token = try await service(server, secrets).accessToken(
            for: destination.id,
            provider: provider(server),
            http: server.http,
            refresh: false
        )
        #expect(token == "good")
        #expect(server.requests.isEmpty)
    }

    @Test func aRevokedSignInIsForgotten() async throws {
        let server = StubServer { _ in .json(
            #"{"error":"invalid_grant","error_description":"refresh token is invalid or revoked"}"#,
            status: 400
        ) }
        let secrets = InMemorySecrets()
        try secrets.setTokens(OAuthTokens(accessToken: "a", refreshToken: "R", expiresAt: .distantPast), for: destination.id)
        let service = service(server, secrets)
        await #expect(throws: UploadError.signInRequired(service: "Dropbox")) {
            try await service.accessToken(for: destination.id, provider: provider(server), http: server.http, refresh: false)
        }
        #expect(try secrets.tokens(for: destination.id) == nil)
    }

    @Test func tokensOfAnotherAppKeyAreNotUsed() async throws {
        let server = StubServer { _ in .empty(500) }
        let secrets = InMemorySecrets()
        try secrets.setTokens(OAuthTokens(accessToken: "a", refreshToken: "R", clientID: "old-key"), for: destination.id)
        let service = service(server, secrets)
        await #expect(throws: UploadError.signInRequired(service: "Dropbox")) {
            try await service.accessToken(for: destination.id, provider: provider(server), http: server.http, refresh: false)
        }
        await #expect(throws: UploadError.signInRequired(service: "Dropbox")) { try await service.checkReady(destination) }
        #expect(server.requests.isEmpty)
    }

    @Test func signingInKeepsTheTokensWithTheAccountAndAppKey() async throws {
        let server = StubServer { request in
            switch request.url.path {
            case "/oauth2/token": .json(#"{"access_token":"A","refresh_token":"R","expires_in":14400,"scope":"files.content.write"}"#)
            case "/2/users/get_current_account": .json(#"{"email":"marcus@example.com","name":{"display_name":"Marcus"}}"#)
            default: .empty(404)
            }
        }
        let secrets = InMemorySecrets()
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        let tokens = try await service(server, secrets).completeSignIn(destination, code: "CODE", pkce: pkce)
        #expect(tokens.account == "Marcus (marcus@example.com)")
        #expect(tokens.clientID == "key")
        #expect(try secrets.tokens(for: destination.id) == tokens)
        let exchange = try FormEncoding.decode(#require(server.requests(to: "/oauth2/token").first).body)
        #expect(exchange["code"] == "CODE")
        #expect(exchange["code_verifier"] == pkce.verifier)
        #expect(server.requests(to: "/2/users/get_current_account").first?.header("Authorization") == "Bearer A")
    }

    @Test func signingOutRevokesAndForgets() async throws {
        let server = StubServer { _ in .json("null") }
        let secrets = InMemorySecrets()
        try secrets.setTokens(OAuthTokens(accessToken: "A", refreshToken: "R"), for: destination.id)
        try await service(server, secrets).signOut(destination)
        #expect(try secrets.tokens(for: destination.id) == nil)
        #expect(server.requests(to: "/2/auth/token/revoke").first?.header("Authorization") == "Bearer A")

        let google = UploadDestination(
            name: "Drive",
            target: .googleDrive(GoogleDriveConfiguration(clientID: "1-a.apps.googleusercontent.com"))
        )
        try secrets.setTokens(OAuthTokens(accessToken: "A", refreshToken: "R"), for: google.id)
        try await service(server, secrets).signOut(google)
        #expect(try FormEncoding.decode(#require(server.requests(to: "/revoke").first).body) == ["token": "R"])
    }

    @Test func aDestinationThatIsNotSignedInSaysSo() async throws {
        let server = StubServer { _ in .empty(500) }
        let service = service(server, InMemorySecrets())
        await #expect(throws: UploadError.signInRequired(service: "Dropbox")) { try await service.checkReady(destination) }
        let empty = UploadDestination(name: "Box", target: .dropbox(DropboxConfiguration()))
        await #expect(throws: UploadError.notConfigured(destination: "Box", missing: "an app key")) { try await service.checkReady(empty) }
    }
}
