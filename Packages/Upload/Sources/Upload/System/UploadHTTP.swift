import Foundation

/// Sends upload requests and returns every HTTP answer, whatever its status, for the destination to read; only a
/// failure to get an answer throws (as an `UploadError`).
///
/// Nothing here logs URLs, headers or bodies: they carry tokens, passwords and the user's file names.
nonisolated struct UploadHTTP: Sendable {
    let session: URLSession

    /// A fresh ephemeral session: no cookies, no cache and no shared credential storage, so a WebDAV password lives
    /// only as long as one upload. Offline fails at once instead of waiting.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 60
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest, delegate: UploadTaskDelegate? = nil) async throws -> (Data, HTTPURLResponse) {
        try await answer(delegate) { try await session.data(for: request, delegate: delegate) }
    }

    /// Streams the file from disk, so a large one is never read into memory.
    func upload(_ request: URLRequest, fromFile file: URL, delegate: UploadTaskDelegate?) async throws -> (Data, HTTPURLResponse) {
        try await answer(delegate) { try await session.upload(for: request, fromFile: file, delegate: delegate) }
    }

    func upload(_ request: URLRequest, from data: Data, delegate: UploadTaskDelegate?) async throws -> (Data, HTTPURLResponse) {
        try await answer(delegate) { try await session.upload(for: request, from: data, delegate: delegate) }
    }

    /// Sends `request` with `body`.
    func send(_ request: URLRequest, body: UploadRequestBody, delegate: UploadTaskDelegate?) async throws -> (Data, HTTPURLResponse) {
        switch body {
        case .none: try await send(request, delegate: delegate)
        case let .file(file): try await upload(request, fromFile: file, delegate: delegate)
        case let .data(data): try await upload(request, from: data, delegate: delegate)
        }
    }

    private func answer(
        _ delegate: UploadTaskDelegate?,
        _ send: () async throws -> (Data, URLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        do {
            let (data, response) = try await send()
            guard let http = response as? HTTPURLResponse else { throw UploadError.failed("The server did not answer over HTTP.") }
            return (data, http)
        } catch {
            if delegate?.refusedCredential == true {
                throw UploadError.unauthorized("The server refused the user name or password.")
            }
            if Task.isCancelled {
                throw UploadError.cancelled
            }
            throw UploadError.from(error)
        }
    }
}
