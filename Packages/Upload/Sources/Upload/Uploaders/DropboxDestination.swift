import Foundation

/// A Dropbox account (`DropboxRequests`): `files/upload` for a file up to 150 MiB, an upload session in 8 MiB chunks
/// above that, then a shared link, made or found, in the form the user picked. A request that meets an expired token
/// gets a fresh one and is sent once more.
nonisolated struct DropboxDestination: DestinationUploader {
    let configuration: DropboxConfiguration
    let http: UploadHTTP
    let endpoints: UploadEndpoints
    /// The access token; `true` asks for a refreshed one.
    let accessToken: @Sendable (_ refresh: Bool) async throws -> String
    /// Dropbox's limits, smaller in tests.
    var singleUploadLimit = DropboxRequests.singleUploadLimit
    var chunkSize = DropboxRequests.chunkSize

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        let target = configuration.folderPath + "/" + UploadPath.joined(path)
        progress(UploadProgress(phase: .connecting))
        let uploaded: String
        if payload.byteCount <= singleUploadLimit {
            let delegate = UploadTaskDelegate(progress: progress, total: payload.byteCount)
            progress(.sending(0, of: payload.byteCount))
            let (body, _) = try await checkedCall(sending: .file(payload.fileURL), delegate: delegate) { try $0.upload(path: target) }
            uploaded = try DropboxResponses.uploadedPath(body)
        } else {
            uploaded = try await uploadInSession(payload, to: target, progress: progress)
        }
        progress(UploadProgress(phase: .finishing))
        let link = try await DropboxLink.link(sharedLink(for: uploaded), style: configuration.linkStyle)
        let folder = UploadPath.segments(configuration.folderPath)
        let segments = UploadPath.segments(uploaded)
        let relative = segments.count > folder.count ? Array(segments.dropFirst(folder.count)) : segments
        return UploadReceipt(link: link, path: relative)
    }

    /// Asks who is signed in, which shows the tokens work.
    func testConnection() async throws -> String {
        let (body, _) = try await checkedCall { try $0.currentAccount() }
        let place = configuration.folderPath.isEmpty ? "the top of the Dropbox" : configuration.folderPath
        let who = DropboxResponses.accountName(body).map { " as \($0)" } ?? ""
        return "Connected\(who). Uploads go to \(place)."
    }

    /// "Marcus Ng (marcus@example.com)" for the tokens, or nil.
    static func accountName(http: UploadHTTP, endpoints: UploadEndpoints, accessToken: String) async -> String? {
        guard let request = try? DropboxRequests(endpoints: endpoints, accessToken: accessToken).currentAccount(),
              let (body, response) = try? await http.send(request), (200 ..< 300).contains(response.statusCode)
        else {
            return nil
        }
        return DropboxResponses.accountName(body)
    }

    /// Big files: the first chunk opens the session, the middle ones are appended at their offsets, and the last one
    /// commits the file.
    private func uploadInSession(
        _ payload: UploadPayload,
        to target: String,
        progress: @escaping UploadProgressHandler
    ) async throws -> String {
        let handle = try FileHandle(forReadingFrom: payload.fileURL)
        defer { try? handle.close() }
        let total = payload.byteCount
        let count = Int((total + chunkSize - 1) / chunkSize)
        var sessionID = ""
        var offset: Int64 = 0
        for index in 0 ..< count {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: Int(chunkSize)) ?? Data()
            let delegate = UploadTaskDelegate(progress: progress, offset: offset, total: total)
            let cursor = DropboxRequests.Cursor(sessionID: sessionID, offset: offset)
            let make: @Sendable (DropboxRequests) throws -> URLRequest = switch index {
            case 0: { try $0.startSession() }
            case count - 1: { try $0.finishSession(cursor, path: target) }
            default: { try $0.appendSession(cursor) }
            }
            let body = try await sendChunk(chunk, delegate: delegate, expectedOffset: offset + Int64(chunk.count), make)
            if index == 0 {
                sessionID = try DropboxResponses.sessionID(body)
            }
            if index == count - 1 {
                return try DropboxResponses.uploadedPath(body)
            }
            offset += Int64(chunk.count)
        }
        throw UploadError.failed("Dropbox did not finish the upload.")
    }

    /// One chunk, sent once more after a dropped connection. When the retry finds Dropbox has the chunk already
    /// (`incorrect_offset` pointing past it), that counts as sent.
    private func sendChunk(
        _ chunk: Data,
        delegate: UploadTaskDelegate,
        expectedOffset: Int64,
        _ make: @escaping @Sendable (DropboxRequests) throws -> URLRequest
    ) async throws -> Data {
        var retried = false
        while true {
            do {
                let (body, response) = try await call(sending: .data(chunk), delegate: delegate, make)
                if response.statusCode == 409, DropboxResponses.correctOffset(body) == expectedOffset {
                    return body
                }
                return try checked((body, response)).0
            } catch let error as UploadError where !retried && error.isConnectionProblem {
                retried = true
            }
        }
    }

    private func sharedLink(for path: String) async throws -> URL {
        let (body, response) = try await call { try $0.createSharedLink(path: path) }
        if (200 ..< 300).contains(response.statusCode) {
            return try DropboxResponses.sharedLink(body)
        }
        guard DropboxResponses.linkAlreadyExists(status: response.statusCode, body: body) else {
            throw DropboxResponses.error(status: response.statusCode, body: body, folder: configuration.folderPath)
        }
        if let existing = DropboxResponses.existingLink(body) {
            return existing
        }
        let (list, _) = try await checkedCall { try $0.listSharedLinks(path: path) }
        guard let link = DropboxResponses.firstLink(list) else { throw UploadError.failed("Dropbox did not send the file's link.") }
        return link
    }

    /// Sends a request built with the current token. A 401 (other than a missing permission) gets a refreshed token
    /// and one more try; whatever comes back then is returned.
    private func call(
        sending body: UploadRequestBody = .none,
        delegate: UploadTaskDelegate? = nil,
        _ make: @Sendable (DropboxRequests) throws -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let token = try await accessToken(false)
        let answer = try await http.send(make(DropboxRequests(endpoints: endpoints, accessToken: token)), body: body, delegate: delegate)
        guard answer.1.statusCode == 401, !DropboxResponses.summary(answer.0).hasPrefix("missing_scope") else { return answer }
        let fresh = try await accessToken(true)
        return try await http.send(make(DropboxRequests(endpoints: endpoints, accessToken: fresh)), body: body, delegate: delegate)
    }

    /// `call`, and an error unless Dropbox answered 2xx.
    private func checkedCall(
        sending body: UploadRequestBody = .none,
        delegate: UploadTaskDelegate? = nil,
        _ make: @Sendable (DropboxRequests) throws -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        try await checked(call(sending: body, delegate: delegate, make))
    }

    private func checked(_ answer: (Data, HTTPURLResponse)) throws -> (Data, HTTPURLResponse) {
        guard (200 ..< 300).contains(answer.1.statusCode) else {
            throw DropboxResponses.error(status: answer.1.statusCode, body: answer.0, folder: configuration.folderPath)
        }
        return answer
    }
}
