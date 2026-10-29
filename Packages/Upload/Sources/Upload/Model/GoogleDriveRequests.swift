import Foundation

/// The Google Drive API v3 requests Oriel sends, built as data so tests can check them: a multipart upload for small
/// files, a resumable one in chunks for large ones, the "Oriel" folder, the "anyone with the link" permission, the
/// account and token revocation. `supportsAllDrives` lets a folder in a shared drive work too.
nonisolated struct GoogleDriveRequests {
    let endpoints: UploadEndpoints
    let accessToken: String

    /// Google's limit for a multipart upload; larger files are resumable.
    static let multipartLimit: Int64 = 5 * 1024 * 1024
    /// Resumable chunks must be multiples of 256 KiB.
    static let chunkSize: Int64 = 32 * 256 * 1024
    /// What the upload answers with: the links come back with the file.
    static let fileFields = "id,name,webViewLink,webContentLink"
    static let folderType = "application/vnd.google-apps.folder"

    /// A file's or folder's metadata.
    struct Metadata: Encodable, Equatable {
        let name: String
        var parents: [String]?
        var mimeType: String?
    }

    private struct Permission: Encodable {
        let role = "reader"
        let type = "anyone"
    }

    func multipartUpload(_ metadata: Metadata, contentType: String, data: Data, boundary: String) throws -> URLRequest {
        var request = try request("POST", endpoints.googleAPI, "/upload/drive/v3/files", query: [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: Self.fileFields),
        ])
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.multipartBody(metadata, contentType: contentType, data: data, boundary: boundary)
        return request
    }

    /// `multipart/related`: the metadata as JSON, then the file (Google's "multipart upload").
    static func multipartBody(_ metadata: Metadata, contentType: String, data: Data, boundary: String) throws -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        try body.append(json(metadata))
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    /// Opens a resumable upload; the answer's `Location` is the session to send the bytes to.
    func startResumable(_ metadata: Metadata, contentType: String, length: Int64) throws -> URLRequest {
        var request = try request("POST", endpoints.googleAPI, "/upload/drive/v3/files", query: [
            URLQueryItem(name: "uploadType", value: "resumable"),
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: Self.fileFields),
        ])
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(contentType, forHTTPHeaderField: "X-Upload-Content-Type")
        request.setValue(String(length), forHTTPHeaderField: "X-Upload-Content-Length")
        request.httpBody = try Self.json(metadata)
        return request
    }

    /// One chunk of a resumable upload: bytes `offset ..< offset + length` of `total`.
    func chunk(session: URL, offset: Int64, length: Int64, total: Int64) -> URLRequest {
        var request = sessionRequest(session)
        request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        request.setValue("bytes \(offset)-\(offset + length - 1)/\(total)", forHTTPHeaderField: "Content-Range")
        return request
    }

    /// Asks how much of a resumable upload arrived, after a chunk failed.
    func status(session: URL, total: Int64) -> URLRequest {
        var request = sessionRequest(session)
        request.setValue("0", forHTTPHeaderField: "Content-Length")
        request.setValue("bytes */\(total)", forHTTPHeaderField: "Content-Range")
        return request
    }

    /// "Anyone with the link can view": `anyone` without file discovery, so the file is not searchable.
    func sharePublicly(fileID: String) throws -> URLRequest {
        var request = try request("POST", endpoints.googleAPI, "/drive/v3/files/\(UploadLinkTemplate.encode(fileID))/permissions", query: [
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: "id"),
        ])
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.json(Permission())
        return request
    }

    /// Looks for a folder Oriel made at the top of My Drive; `drive.file` shows only those.
    func findFolder(named name: String) throws -> URLRequest {
        let escaped = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let query = "name = '\(escaped)' and mimeType = '\(Self.folderType)' and 'root' in parents and trashed = false"
        return try request("GET", endpoints.googleAPI, "/drive/v3/files", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "fields", value: "files(id)"),
            URLQueryItem(name: "pageSize", value: "1"),
        ])
    }

    func createFolder(named name: String) throws -> URLRequest {
        var request = try request("POST", endpoints.googleAPI, "/drive/v3/files", query: [URLQueryItem(name: "fields", value: "id")])
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.json(Metadata(name: name, mimeType: Self.folderType))
        return request
    }

    /// A folder's name and type, which also shows Oriel may use it.
    func folder(id: String) throws -> URLRequest {
        try request("GET", endpoints.googleAPI, "/drive/v3/files/\(UploadLinkTemplate.encode(id))", query: [
            URLQueryItem(name: "supportsAllDrives", value: "true"),
            URLQueryItem(name: "fields", value: "id,name,mimeType"),
        ])
    }

    /// Who is signed in, for Settings.
    func about() throws -> URLRequest {
        try request(
            "GET",
            endpoints.googleAPI,
            "/drive/v3/about",
            query: [URLQueryItem(name: "fields", value: "user(displayName,emailAddress)")]
        )
    }

    /// Revoking the refresh token ends the whole sign-in.
    func revoke(token: String) throws -> URLRequest {
        var request = try URLRequest(
            url: UploadEndpoints.url(endpoints.googleRevoke),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormEncoding.body([URLQueryItem(name: "token", value: token)])
        return request
    }

    private func request(_ method: String, _ base: String, _ path: String, query: [URLQueryItem]) throws -> URLRequest {
        var request = try URLRequest(
            url: UploadEndpoints.url(base, path, query: query),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60
        )
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func sessionRequest(_ session: URL) -> URLRequest {
        var request = URLRequest(url: session, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func json(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
