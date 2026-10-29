import Foundation

/// The Dropbox API v2 requests Oriel sends, built as data so tests can check them: uploads (`files/upload` up to
/// 150 MiB, an upload session above that), shared links, the account and token revocation. Content endpoints take
/// their arguments in `Dropbox-API-Arg`; RPC endpoints take a JSON body.
nonisolated struct DropboxRequests {
    let endpoints: UploadEndpoints
    let accessToken: String

    /// `files/upload` takes at most 150 MiB; bigger files go up in an upload session.
    static let singleUploadLimit: Int64 = 150 * 1024 * 1024
    /// Session chunks: a multiple of 4 MiB, as Dropbox recommends.
    static let chunkSize: Int64 = 8 * 1024 * 1024

    /// What to do with a new file: never overwrite; rename it when the name is taken; don't notify the user's devices.
    struct Commit: Encodable, Equatable {
        let path: String
        var mode = "add"
        var autorename = true
        var mute = true
        var strictConflict = false

        enum CodingKeys: String, CodingKey {
            case path, mode, autorename, mute
            case strictConflict = "strict_conflict"
        }
    }

    struct Cursor: Encodable, Equatable {
        let sessionID: String
        let offset: Int64

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case offset
        }
    }

    private struct StartArg: Encodable {
        var close = false
    }

    private struct AppendArg: Encodable {
        let cursor: Cursor
        var close = false
    }

    private struct FinishArg: Encodable {
        let cursor: Cursor
        let commit: Commit
    }

    private struct PathArg: Encodable {
        let path: String
    }

    private struct ListLinksArg: Encodable {
        let path: String
        var directOnly = true

        enum CodingKeys: String, CodingKey {
            case path
            case directOnly = "direct_only"
        }
    }

    func upload(path: String) throws -> URLRequest {
        try content("/2/files/upload", argument: Commit(path: path))
    }

    func startSession() throws -> URLRequest {
        try content("/2/files/upload_session/start", argument: StartArg())
    }

    func appendSession(_ cursor: Cursor) throws -> URLRequest {
        try content("/2/files/upload_session/append_v2", argument: AppendArg(cursor: cursor))
    }

    func finishSession(_ cursor: Cursor, path: String) throws -> URLRequest {
        try content("/2/files/upload_session/finish", argument: FinishArg(cursor: cursor, commit: Commit(path: path)))
    }

    /// A link with the account's default settings; a team may make it team-only.
    func createSharedLink(path: String) throws -> URLRequest {
        try rpc("/2/sharing/create_shared_link_with_settings", body: PathArg(path: path))
    }

    /// The links a file already has, for when creating one says it exists.
    func listSharedLinks(path: String) throws -> URLRequest {
        try rpc("/2/sharing/list_shared_links", body: ListLinksArg(path: path))
    }

    func currentAccount() throws -> URLRequest {
        try rpc("/2/users/get_current_account", body: nil as PathArg?)
    }

    func revoke() throws -> URLRequest {
        try rpc("/2/auth/token/revoke", body: nil as PathArg?)
    }

    /// A content endpoint: arguments in the header, the bytes as the body.
    private func content(_ path: String, argument: some Encodable) throws -> URLRequest {
        var request = try base(UploadEndpoints.url(endpoints.dropboxContent, path))
        try request.setValue(DropboxAPIArg.header(argument), forHTTPHeaderField: "Dropbox-API-Arg")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// An RPC endpoint: JSON in, JSON out. One without arguments takes no body at all.
    private func rpc(_ path: String, body: (some Encodable)?) throws -> URLRequest {
        var request = try base(UploadEndpoints.url(endpoints.dropboxAPI, path))
        if let body {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func base(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }
}
