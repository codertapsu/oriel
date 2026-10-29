import CoreGraphics
import Foundation
import OrielCore
import os

/// Runs uploads, connection tests and sign-ins off the main thread (PLAN §6.4): it prepares the file, checks the
/// destination is ready, makes the destination's uploader with its secrets and a fresh session, and keeps the OAuth
/// access tokens, refreshing each destination's at most once at a time.
actor UploadService {
    private let secrets: any UploadSecretStoring
    private let runner: any ProcessRunning
    private let endpoints: UploadEndpoints
    private let makeSession: @Sendable () -> URLSession
    private let knownFolders = KnownFolders()
    private var tokens: [UUID: OAuthTokens] = [:]
    private var refreshes: [UUID: Task<OAuthTokens, any Error>] = [:]
    private let log = Log.logger("upload")

    init(
        secrets: any UploadSecretStoring,
        runner: any ProcessRunning = SystemProcessRunner(),
        endpoints: UploadEndpoints = .production,
        makeSession: @escaping @Sendable () -> URLSession = UploadHTTP.makeSession
    ) {
        self.secrets = secrets
        self.runner = runner
        self.endpoints = endpoints
        self.makeSession = makeSession
    }

    // MARK: Files

    func prepare(image: CGImage, scale: CGFloat, name: String) throws -> UploadPayload {
        try PayloadPreparer.image(image, scale: scale, name: name)
    }

    func prepare(fileAt url: URL, stripsMetadata: Bool) throws -> UploadPayload {
        try PayloadPreparer.file(at: url, stripsMetadata: stripsMetadata)
    }

    func discard(_ payload: UploadPayload) {
        PayloadPreparer.cleanUp(payload)
    }

    // MARK: Uploads

    /// Sends `payload` to `destination`, named by its template at `date`.
    func upload(
        _ payload: UploadPayload,
        to destination: UploadDestination,
        date: Date = Date(),
        progress: @escaping UploadProgressHandler
    ) async throws -> UploadReceipt {
        let path = UploadNameTemplate.render(
            destination.nameTemplate, context: UploadNameTemplate.Context(name: payload.name, date: date),
            fileExtension: payload.fileExtension
        )
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        let uploader = try uploader(for: destination, http: UploadHTTP(session: session))
        return try await uploader.upload(payload, to: path, progress: progress)
    }

    func testConnection(_ destination: UploadDestination) async throws -> String {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        return try await uploader(for: destination, http: UploadHTTP(session: session)).testConnection()
    }

    /// Throws what keeps `destination` from uploading: a missing setting, a setting that cannot work, or a missing
    /// secret or sign-in.
    func checkReady(_ destination: UploadDestination) throws {
        if let missing = destination.target.missingField {
            throw UploadError.notConfigured(destination: destination.displayName, missing: missing)
        }
        if let problem = destination.target.problem {
            throw UploadError.invalidSettings(problem)
        }
        switch destination.target {
        case .s3:
            guard try secret(.secretKey, of: destination) != nil else {
                throw UploadError.missingSecret(destination: destination.displayName, secret: UploadSecret.secretKey.title)
            }
        case let .webDAV(configuration) where !configuration.username.trimmingCharacters(in: .whitespaces).isEmpty:
            guard try secret(.password, of: destination) != nil else {
                throw UploadError.missingSecret(destination: destination.displayName, secret: UploadSecret.password.title)
            }
        case .dropbox, .googleDrive:
            guard let current = try tokens[destination.id] ?? storedTokens(destination.id),
                  current.belongs(to: destination.target.oauthClientID ?? "")
            else {
                throw UploadError.signInRequired(service: destination.kind.title)
            }
        case .webDAV, .sftp, .sharedFolder:
            break
        }
    }

    private func uploader(for destination: UploadDestination, http: UploadHTTP) throws -> any DestinationUploader {
        try checkReady(destination)
        switch destination.target {
        case let .s3(configuration):
            return try S3Destination(configuration: configuration, secretKey: secret(.secretKey, of: destination) ?? "", http: http)
        case let .webDAV(configuration):
            return try WebDAVDestination(
                id: destination.id, configuration: configuration, password: secret(.password, of: destination), http: http,
                knownFolders: knownFolders
            )
        case let .sftp(configuration):
            return SFTPDestination(configuration: configuration, runner: runner)
        case let .sharedFolder(configuration):
            return SharedFolderDestination(configuration: configuration)
        case let .dropbox(configuration):
            let provider = try OAuthProvider.dropbox(configuration, endpoints: endpoints)
            return DropboxDestination(configuration: configuration, http: http, endpoints: endpoints) { [id = destination.id] refresh in
                try await self.accessToken(for: id, provider: provider, http: http, refresh: refresh)
            }
        case let .googleDrive(configuration):
            let provider = try OAuthProvider.googleDrive(configuration, endpoints: endpoints)
            return GoogleDriveDestination(configuration: configuration, http: http, endpoints: endpoints) { [id = destination.id] refresh in
                try await self.accessToken(for: id, provider: provider, http: http, refresh: refresh)
            }
        }
    }

    private func secret(_ secret: UploadSecret, of destination: UploadDestination) throws -> String? {
        do {
            return try secrets.string(secret, for: destination.id)
        } catch {
            throw UploadError.keychain(error.localizedDescription)
        }
    }

    // MARK: Sign-in

    /// The sign-in page to open for `destination`, with the verifier and state to check its answer with.
    nonisolated static func authorization(for destination: UploadDestination, endpoints: UploadEndpoints) throws -> OAuthAuthorization {
        let provider = try oauthProvider(for: destination, endpoints: endpoints)
        let pkce = PKCE.generate()
        let state = UploadNameTemplate.randomToken()
        return try OAuthAuthorization(
            url: provider.authorizationURL(pkce: pkce, state: state), callbackScheme: provider.callbackScheme, pkce: pkce, state: state,
            service: provider.service
        )
    }

    nonisolated static func oauthProvider(for destination: UploadDestination, endpoints: UploadEndpoints) throws -> OAuthProvider {
        switch destination.target {
        case let .dropbox(configuration): try .dropbox(configuration, endpoints: endpoints)
        case let .googleDrive(configuration): try .googleDrive(configuration, endpoints: endpoints)
        default: throw UploadError.invalidSettings("\(destination.kind.title) doesn't sign in with a browser.")
        }
    }

    var oauthEndpoints: UploadEndpoints {
        endpoints
    }

    /// Trades the code from the sign-in's redirect for tokens, finds out who signed in, and keeps the tokens.
    func completeSignIn(_ destination: UploadDestination, code: String, pkce: PKCE) async throws -> OAuthTokens {
        let provider = try Self.oauthProvider(for: destination, endpoints: endpoints)
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        let http = UploadHTTP(session: session)
        let (data, response) = try await http.send(provider.codeExchangeRequest(code: code, pkce: pkce))
        var fresh = try OAuthTokenResponse.parse(data, status: response.statusCode, service: provider.service).tokens(now: Date())
        fresh.clientID = provider.clientID
        fresh.account = switch destination.kind {
        case .dropbox: await DropboxDestination.accountName(http: http, endpoints: endpoints, accessToken: fresh.accessToken)
        default: await GoogleDriveDestination.accountName(http: http, endpoints: endpoints, accessToken: fresh.accessToken)
        }
        do {
            try secrets.setTokens(fresh, for: destination.id)
        } catch {
            throw UploadError.keychain(error.localizedDescription)
        }
        tokens[destination.id] = fresh
        refreshes[destination.id] = nil
        return fresh
    }

    /// Forgets the tokens and asks the service to revoke them; the revocation is best effort, the forgetting is not.
    func signOut(_ destination: UploadDestination) async throws {
        let stored = try tokens[destination.id] ?? storedTokens(destination.id)
        tokens[destination.id] = nil
        do {
            try secrets.setTokens(nil, for: destination.id)
        } catch {
            throw UploadError.keychain(error.localizedDescription)
        }
        if let stored {
            await revoke(stored, of: destination)
        }
    }

    /// Asks the service to end the sign-in `tokens` belong to, and forgets them here; for sign-out and for a deleted
    /// destination, whose Keychain items are gone already. Best effort: a failure is only logged.
    func revoke(_ tokens: OAuthTokens, of destination: UploadDestination) async {
        self.tokens[destination.id] = nil
        guard let request = revocation(of: tokens, for: destination.kind) else { return }
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        if let (_, response) = try? await UploadHTTP(session: session).send(request), !(200 ..< 300).contains(response.statusCode) {
            let kind = destination.kind.rawValue
            let status = response.statusCode
            log.notice("revoking the \(kind, privacy: .public) sign-in answered \(status, privacy: .public)")
        }
    }

    /// Dropbox revokes the access token's sign-in; Google revokes the refresh token, which ends the whole sign-in.
    private func revocation(of tokens: OAuthTokens, for kind: UploadDestinationKind) -> URLRequest? {
        switch kind {
        case .dropbox:
            return try? DropboxRequests(endpoints: endpoints, accessToken: tokens.accessToken).revoke()
        case .googleDrive:
            let requests = GoogleDriveRequests(endpoints: endpoints, accessToken: tokens.accessToken)
            return try? requests.revoke(token: tokens.refreshToken ?? tokens.accessToken)
        default:
            return nil
        }
    }

    // MARK: Tokens

    private func storedTokens(_ id: UUID) throws -> OAuthTokens? {
        do {
            return try secrets.tokens(for: id)
        } catch {
            throw UploadError.keychain(error.localizedDescription)
        }
    }

    /// The access token for `id`: the one in hand while it is valid, else a refreshed one. Callers that find the
    /// service refusing a token ask with `refresh`. A refresh that finds the sign-in revoked forgets the tokens, so
    /// Settings shows it is gone; a sign-in or sign-out that happens during a refresh wins over it.
    func accessToken(for id: UUID, provider: OAuthProvider, http: UploadHTTP, refresh: Bool) async throws -> String {
        if let running = refreshes[id] {
            return try await running.value.accessToken
        }
        guard let current = try tokens[id] ?? storedTokens(id), current.belongs(to: provider.clientID) else {
            throw UploadError.signInRequired(service: provider.service)
        }
        tokens[id] = current
        if !refresh, !current.isExpired() {
            return current.accessToken
        }
        guard let refreshToken = current.refreshToken else {
            try? forget(id)
            throw UploadError.signInRequired(service: provider.service)
        }
        let task = Task<OAuthTokens, any Error> {
            let (data, response) = try await http.send(provider.refreshRequest(refreshToken: refreshToken))
            let answer = try OAuthTokenResponse.parse(data, status: response.statusCode, service: provider.service)
            return current.refreshed(with: answer, now: Date())
        }
        refreshes[id] = task
        defer {
            if refreshes[id] == task {
                refreshes[id] = nil
            }
        }
        do {
            let fresh = try await task.value
            if tokens[id] == current {
                keep(fresh, for: id)
            }
            return fresh.accessToken
        } catch let UploadError.signInRequired(service) {
            if tokens[id] == current {
                try? forget(id)
            }
            throw UploadError.signInRequired(service: service)
        }
    }

    private func keep(_ fresh: OAuthTokens, for id: UUID) {
        tokens[id] = fresh
        do {
            try secrets.setTokens(fresh, for: id)
        } catch {
            log.error("a refreshed token could not be kept: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func forget(_ id: UUID) throws {
        tokens[id] = nil
        try secrets.setTokens(nil, for: id)
    }
}
