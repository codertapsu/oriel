import Foundation

/// A Google Drive (`GoogleDriveRequests`): a multipart upload up to 5 MB, a resumable one in 8 MiB chunks above that
/// (a failed chunk resumes from where Google says it got to), into the chosen folder or an "Oriel" folder Oriel makes
/// once, then optionally "anyone with the link can view". A request that meets an expired token gets a fresh one and
/// is sent once more.
nonisolated struct GoogleDriveDestination: DestinationUploader {
    let configuration: GoogleDriveConfiguration
    let http: UploadHTTP
    let endpoints: UploadEndpoints
    /// The access token; `true` asks for a refreshed one.
    let accessToken: @Sendable (_ refresh: Bool) async throws -> String
    /// Google's limits, smaller in tests.
    var multipartLimit = GoogleDriveRequests.multipartLimit
    var chunkSize = GoogleDriveRequests.chunkSize

    /// The folder Oriel makes when no folder is set.
    static let folderName = "Oriel"
    /// Resumable chunks retried after a dropped connection or a server error.
    static let retries = 3

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        progress(UploadProgress(phase: .connecting))
        var updated: GoogleDriveConfiguration?
        let parent: String
        if !configuration.resolvedFolderID.isEmpty {
            parent = configuration.resolvedFolderID
        } else if let made = configuration.createdFolderID, !made.isEmpty {
            parent = made
        } else {
            parent = try await findOrMakeFolder()
            var changed = configuration
            changed.createdFolderID = parent
            updated = changed
        }
        // Drive has folders but no paths: the template's folders become part of the name.
        let name = path.joined(separator: " ")
        let metadata = GoogleDriveRequests.Metadata(name: name, parents: [parent])
        let file = if payload.byteCount <= multipartLimit {
            try await uploadMultipart(payload, metadata: metadata, progress: progress)
        } else {
            try await uploadResumable(payload, metadata: metadata, progress: progress)
        }
        var notice: String?
        if configuration.sharesPublicly {
            progress(UploadProgress(phase: .finishing))
            notice = await sharePublicly(file.id)
        }
        let preferred = configuration.linkStyle == .download ? file.webContentLink ?? file.webViewLink : file.webViewLink
        guard let link = preferred ?? URL(string: "https://drive.google.com/file/d/\(UploadLinkTemplate.encode(file.id))/view") else {
            throw UploadError.failed("Google Drive did not send the file's link.")
        }
        let target = updated.map(UploadTarget.googleDrive)
        return UploadReceipt(link: link, path: [file.name.isEmpty ? name : file.name], notice: notice, updatedTarget: target)
    }

    /// Asks who is signed in and, when a folder is set, whether Oriel may use it.
    func testConnection() async throws -> String {
        let (body, _) = try await checkedCall { try $0.about() }
        let who = GoogleDriveResponses.accountName(body).map { " as \($0)" } ?? ""
        let folderID = configuration.resolvedFolderID
        guard !folderID.isEmpty else {
            return "Connected\(who). Uploads go to the “\(Self.folderName)” folder in My Drive."
        }
        let (folder, _) = try await checkedCall { try $0.folder(id: folderID) }
        let object = (try? JSONSerialization.jsonObject(with: folder)) as? [String: Any]
        guard object?["mimeType"] as? String == GoogleDriveRequests.folderType else {
            throw UploadError.invalidSettings("That ID belongs to a file, not a folder.")
        }
        let name = object?["name"] as? String ?? folderID
        return "Connected\(who). Uploads go to “\(name)”."
    }

    /// "Marcus Ng (marcus@example.com)" for the tokens, or nil.
    static func accountName(http: UploadHTTP, endpoints: UploadEndpoints, accessToken: String) async -> String? {
        guard let request = try? GoogleDriveRequests(endpoints: endpoints, accessToken: accessToken).about(),
              let (body, response) = try? await http.send(request), (200 ..< 300).contains(response.statusCode)
        else {
            return nil
        }
        return GoogleDriveResponses.accountName(body)
    }

    private func findOrMakeFolder() async throws -> String {
        let (list, _) = try await checkedCall { try $0.findFolder(named: Self.folderName) }
        if let id = GoogleDriveResponses.firstFileID(list) {
            return id
        }
        let (body, _) = try await checkedCall { try $0.createFolder(named: Self.folderName) }
        return try GoogleDriveResponses.file(body).id
    }

    private func uploadMultipart(
        _ payload: UploadPayload,
        metadata: GoogleDriveRequests.Metadata,
        progress: @escaping UploadProgressHandler
    ) async throws -> GoogleDriveResponses.File {
        let data = try Data(contentsOf: payload.fileURL)
        let boundary = "oriel-\(UUID().uuidString)"
        let delegate = UploadTaskDelegate(progress: progress)
        progress(.sending(0, of: payload.byteCount))
        let (body, _) = try await checkedCall(delegate: delegate) {
            try $0.multipartUpload(metadata, contentType: payload.contentType, data: data, boundary: boundary)
        }
        return try GoogleDriveResponses.file(body)
    }

    /// Where a resumable upload stands after a chunk.
    private enum Resume {
        case finished(GoogleDriveResponses.File)
        case at(Int64)
        /// The chunk failed on the way or with a server error: ask Google where the upload is, then go on.
        case lost
    }

    /// Opens a session, then sends the file a chunk at a time. Google answers 308 with the bytes it has after each
    /// chunk but the last; after a failure Oriel asks where the upload is and goes on from there.
    private func uploadResumable(
        _ payload: UploadPayload,
        metadata: GoogleDriveRequests.Metadata,
        progress: @escaping UploadProgressHandler
    ) async throws -> GoogleDriveResponses.File {
        let total = payload.byteCount
        let (_, opened) = try await checkedCall { try $0.startResumable(metadata, contentType: payload.contentType, length: total) }
        guard let location = opened.value(forHTTPHeaderField: "Location"), let session = URL(string: location) else {
            throw UploadError.failed("Google Drive did not open the upload.")
        }
        let handle = try FileHandle(forReadingFrom: payload.fileURL)
        defer { try? handle.close() }
        var offset: Int64 = 0
        var failures = 0
        while true {
            try Task.checkCancellation()
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: Int(chunkSize)) ?? Data()
            let delegate = UploadTaskDelegate(progress: progress, offset: offset, total: total)
            let mayRetry = failures < Self.retries
            var state: Resume
            do {
                state = try await send(chunk, at: offset, of: total, to: session, delegate: delegate, mayRetry: mayRetry)
            } catch let error as UploadError where error.isConnectionProblem && mayRetry {
                state = .lost
            }
            if case .lost = state {
                failures += 1
                state = try await resume(session, total: total)
            } else {
                failures = 0
            }
            switch state {
            case let .finished(file): return file
            case let .at(next): offset = next
            case .lost: throw UploadError.failed("Google Drive lost track of the upload. Try again.")
            }
        }
    }

    /// One chunk of a resumable upload, and where the upload stands after it. A server error is `lost` while another
    /// try is allowed.
    private func send(
        _ chunk: Data,
        at offset: Int64,
        of total: Int64,
        to session: URL,
        delegate: UploadTaskDelegate,
        mayRetry: Bool
    ) async throws -> Resume {
        let length = Int64(chunk.count)
        let (body, response) = try await call(sending: .data(chunk), delegate: delegate) {
            $0.chunk(session: session, offset: offset, length: length, total: total)
        }
        switch response.statusCode {
        case 200, 201: return try .finished(GoogleDriveResponses.file(body))
        case 308: return .at(GoogleDriveResponses.nextOffset(range: response.value(forHTTPHeaderField: "Range")))
        case 500 ... 599 where mayRetry: return .lost
        default: throw GoogleDriveResponses.error(status: response.statusCode, body: body)
        }
    }

    private func resume(_ session: URL, total: Int64) async throws -> Resume {
        let (body, response) = try await call { $0.status(session: session, total: total) }
        switch response.statusCode {
        case 200, 201: return try .finished(GoogleDriveResponses.file(body))
        case 308: return .at(GoogleDriveResponses.nextOffset(range: response.value(forHTTPHeaderField: "Range")))
        default: throw GoogleDriveResponses.error(status: response.statusCode, body: body)
        }
    }

    /// Gives anyone with the link read access. A domain that forbids it does not fail the upload: the link still works
    /// for the people the file is shared with, and the notice says so.
    private func sharePublicly(_ fileID: String) async -> String? {
        do {
            _ = try await checkedCall { try $0.sharePublicly(fileID: fileID) }
            return nil
        } catch {
            let reason = UploadError.from(error).localizedDescription
            return "Google Drive kept the file private: \(reason) The link works for people the file is shared with."
        }
    }

    /// Sends a request built with the current token; a 401 gets a refreshed token and one more try.
    private func call(
        sending body: UploadRequestBody = .none,
        delegate: UploadTaskDelegate? = nil,
        _ make: @Sendable (GoogleDriveRequests) throws -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let token = try await accessToken(false)
        let answer = try await http.send(
            make(GoogleDriveRequests(endpoints: endpoints, accessToken: token)),
            body: body,
            delegate: delegate
        )
        guard answer.1.statusCode == 401 else { return answer }
        let fresh = try await accessToken(true)
        return try await http.send(make(GoogleDriveRequests(endpoints: endpoints, accessToken: fresh)), body: body, delegate: delegate)
    }

    /// `call`, and an error unless Google answered 2xx.
    private func checkedCall(
        sending body: UploadRequestBody = .none,
        delegate: UploadTaskDelegate? = nil,
        _ make: @Sendable (GoogleDriveRequests) throws -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let answer = try await call(sending: body, delegate: delegate, make)
        guard (200 ..< 300).contains(answer.1.statusCode) else {
            throw GoogleDriveResponses.error(status: answer.1.statusCode, body: answer.0)
        }
        return answer
    }
}
