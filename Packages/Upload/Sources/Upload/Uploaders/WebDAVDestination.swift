import Foundation

/// A WebDAV server: `MKCOL` for each folder that is not there yet, then a `PUT` of the file, streamed from disk.
/// The server picks Basic or Digest, and URLSession answers its challenge with the user name and the password from
/// the Keychain (`UploadTaskDelegate`); the credential lives only in this upload's session.
nonisolated struct WebDAVDestination: DestinationUploader {
    let id: UUID
    let configuration: WebDAVConfiguration
    let password: String?
    let http: UploadHTTP
    let knownFolders: KnownFolders

    /// Tries this many names ("Shot.png", "Shot 2.png"…) when the server already has a file by that name.
    static let attempts = 5

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        let server = try server()
        progress(UploadProgress(phase: .connecting))
        try await makeFolders(WebDAVRequests.foldersToMake(folder: configuration.folderSegments, path: path), on: server)
        for number in 1 ... Self.attempts {
            let finalPath = UploadRename.numbered(path, number)
            guard let url = WebDAVRequests.url(server: server, segments: configuration.folderSegments + finalPath, isFolder: false) else {
                throw UploadError.invalidSettings("The server address is not a valid URL.")
            }
            let delegate = UploadTaskDelegate(progress: progress, total: payload.byteCount, credential: credential)
            progress(.sending(0, of: payload.byteCount))
            let request = WebDAVRequests.put(url, contentType: payload.contentType, length: payload.byteCount)
            let (body, response) = try await http.upload(request, fromFile: payload.fileURL, delegate: delegate)
            switch response.statusCode {
            case 200 ..< 300:
                let link = UploadLinkTemplate.link(configuration.publicURLTemplate, path: finalPath) ?? url
                return UploadReceipt(link: link, path: finalPath)
            case 412:
                continue
            default:
                throw error(status: response.statusCode, body: body)
            }
        }
        throw UploadError.failed("The folder already has files named like this one. Add {random} or {time} to the file name.")
    }

    /// `PROPFIND` on the folder; when it is not there yet, on the server address, since the first upload makes it.
    func testConnection() async throws -> String {
        let server = try server()
        let folder = configuration.folderSegments
        let place = folder.isEmpty ? "the server's top folder" : "“\(UploadPath.joined(folder))”"
        switch try await propfind(folder, on: server) {
        case .folder, .unknown:
            return "Connected. Uploads go to \(place)."
        case .file:
            throw UploadError.invalidSettings("\(place) on the server is a file, not a folder.")
        case nil where !folder.isEmpty:
            guard try await propfind([], on: server) != nil else {
                throw UploadError.notFound("The server has nothing at that address. Check the server address.")
            }
            return "Connected. Oriel makes the folder \(place) with the first upload."
        case nil:
            throw UploadError.notFound("The server has nothing at that address. Check the server address.")
        }
    }

    private var credential: URLCredential? {
        let user = configuration.username.trimmingCharacters(in: .whitespaces)
        guard !user.isEmpty else { return nil }
        return URLCredential(user: user, password: password ?? "", persistence: .forSession)
    }

    private func server() throws -> URL {
        guard let server = configuration.server else { throw UploadError.notConfigured(destination: "WebDAV", missing: "a server address") }
        return server
    }

    /// The resource at `segments`, or nil when there is none (404).
    private func propfind(_ segments: [String], on server: URL) async throws -> WebDAVMultistatus.Resource? {
        guard let url = WebDAVRequests.url(server: server, segments: segments, isFolder: true) else {
            throw UploadError.invalidSettings("The server address is not a valid URL.")
        }
        let delegate = UploadTaskDelegate(progress: nil, credential: credential)
        let (body, response) = try await http.send(WebDAVRequests.propfind(url), delegate: delegate)
        switch response.statusCode {
        case 207: return WebDAVMultistatus.resource(in: body)
        case 200 ..< 300: return .unknown
        case 404: return nil
        default: throw error(status: response.statusCode, body: body)
        }
    }

    /// Makes each folder in turn; one that exists answers 405, which is fine. The configured folder is remembered, so
    /// the next upload does not ask again.
    private func makeFolders(_ folders: [[String]], on server: URL) async throws {
        let scope = "\(id.uuidString) \(server.absoluteString)"
        for folder in folders where !knownFolders.contains(folder, in: scope) {
            guard let url = WebDAVRequests.url(server: server, segments: folder, isFolder: true) else {
                throw UploadError.invalidSettings("The server address is not a valid URL.")
            }
            let delegate = UploadTaskDelegate(progress: nil, credential: credential)
            let (body, response) = try await http.send(WebDAVRequests.mkcol(url), delegate: delegate)
            switch response.statusCode {
            case 200 ..< 300, 301, 302, 405:
                if folder.count <= configuration.folderSegments.count {
                    knownFolders.insert(folder, in: scope)
                }
            case 409:
                throw UploadError.notFound("The server has no folder at that address. Check the server address.")
            default:
                throw error(status: response.statusCode, body: body)
            }
        }
    }

    private func error(status: Int, body: Data) -> UploadError {
        let place = configuration.folderSegments.isEmpty ? "that folder" : "“\(UploadPath.joined(configuration.folderSegments))”"
        switch status {
        case 401: return .unauthorized("The server refused the user name or password.")
        case 403: return .forbidden("The server doesn't let this account write to \(place).")
        case 404: return .notFound("The server has no folder at that address. Check the server address.")
        case 405, 501:
            return .invalidSettings("The server doesn't take WebDAV uploads at that address. Check the server address.")
        case 409: return .notFound("A folder on the way to the file doesn't exist on the server.")
        case 423: return .failed("The file is locked on the server.")
        case 507: return .quotaExceeded("The server has no space left.")
        default:
            let text = body.prefix(200).utf8Text.trimmingCharacters(in: .whitespacesAndNewlines)
            return UploadError.from(status: status, message: text.hasPrefix("<") ? "" : text)
        }
    }
}
