import Foundation
import Testing
@testable import Upload

struct GoogleDriveTests {
    @Test func theMultipartBodyIsMetadataThenTheFile() throws {
        let metadata = GoogleDriveRequests.Metadata(name: "Safari 2026-10-29.png", parents: ["F1"])
        let body = try GoogleDriveRequests.multipartBody(metadata, contentType: "image/png", data: Data("PNG".utf8), boundary: "B")
        let expected = "--B\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n"
            + #"{"name":"Safari 2026-10-29.png","parents":["F1"]}"#
            + "\r\n--B\r\nContent-Type: image/png\r\n\r\nPNG\r\n--B--\r\n"
        #expect(body.utf8Text == expected)

        let request = try GoogleDriveRequests(endpoints: .production, accessToken: "T")
            .multipartUpload(metadata, contentType: "image/png", data: Data("PNG".utf8), boundary: "B")
        let url = try #require(request.url)
        #expect(url.absoluteString.hasPrefix("https://www.googleapis.com/upload/drive/v3/files?"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "uploadType" }?.value == "multipart")
        #expect(items.first { $0.name == "supportsAllDrives" }?.value == "true")
        #expect(items.first { $0.name == "fields" }?.value == "id,name,webViewLink,webContentLink")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/related; boundary=B")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer T")
    }

    @Test func aResumableUploadOpensASessionAndSendsRanges() throws {
        let requests = GoogleDriveRequests(endpoints: .production, accessToken: "T")
        let start = try requests.startResumable(
            GoogleDriveRequests.Metadata(name: "a.mov", parents: ["F"]),
            contentType: "video/quicktime",
            length: 20_000_000
        )
        #expect(start.httpMethod == "POST")
        #expect(start.url?.query?.contains("uploadType=resumable") == true)
        #expect(start.value(forHTTPHeaderField: "X-Upload-Content-Type") == "video/quicktime")
        #expect(start.value(forHTTPHeaderField: "X-Upload-Content-Length") == "20000000")
        #expect((start.httpBody ?? Data()).utf8Text == #"{"name":"a.mov","parents":["F"]}"#)
        let session = try #require(URL(string: "https://www.googleapis.com/upload/drive/v3/files?upload_id=X"))
        let chunk = requests.chunk(session: session, offset: 8_388_608, length: 8_388_608, total: 20_000_000)
        #expect(chunk.httpMethod == "PUT")
        #expect(chunk.value(forHTTPHeaderField: "Content-Range") == "bytes 8388608-16777215/20000000")
        #expect(requests.status(session: session, total: 20_000_000).value(forHTTPHeaderField: "Content-Range") == "bytes */20000000")
        #expect(GoogleDriveRequests.chunkSize % (256 * 1024) == 0)
        #expect(GoogleDriveResponses.nextOffset(range: "bytes=0-8388607") == 8_388_608)
        #expect(GoogleDriveResponses.nextOffset(range: nil) == 0)
    }

    @Test func sharingIsAnyoneWithTheLinkAsReader() throws {
        let request = try GoogleDriveRequests(endpoints: .production, accessToken: "T").sharePublicly(fileID: "abc")
        #expect(request.url?.path == "/drive/v3/files/abc/permissions")
        #expect((request.httpBody ?? Data()).utf8Text == #"{"role":"reader","type":"anyone"}"#)
        let find = try GoogleDriveRequests(endpoints: .production, accessToken: "T").findFolder(named: "Oriel")
        let query = try URLComponents(url: #require(find.url), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
        #expect(query == "name = 'Oriel' and mimeType = 'application/vnd.google-apps.folder' and 'root' in parents and trashed = false")
    }

    @Test func folderLinksGiveTheirID() {
        #expect(GoogleDriveConfiguration.folderID(from: "1AbCdEf") == "1AbCdEf")
        #expect(GoogleDriveConfiguration.folderID(from: "https://drive.google.com/drive/folders/1AbCdEf?usp=sharing") == "1AbCdEf")
        #expect(GoogleDriveConfiguration.folderID(from: "https://drive.google.com/drive/u/1/folders/1XyZ") == "1XyZ")
        #expect(GoogleDriveConfiguration.folderID(from: "https://drive.google.com/open?id=1Q") == "1Q")
        #expect(GoogleDriveConfiguration.folderID(from: "  ") == "")
    }

    private func destination(_ server: StubServer, _ configuration: GoogleDriveConfiguration) -> GoogleDriveDestination {
        GoogleDriveDestination(configuration: configuration, http: server.http, endpoints: server.endpoints) { _ in "T" }
    }

    private static let file = #"""
    {"id": "FILE", "name": "Safari.png",
     "webViewLink": "https://drive.google.com/file/d/FILE/view?usp=drivesdk",
     "webContentLink": "https://drive.google.com/uc?id=FILE&export=download"}
    """#

    @Test func theFirstUploadMakesAnOrielFolderAndSharesTheFile() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { request in
            switch (request.method, request.url.path) {
            case ("GET", "/drive/v3/files"): .json(#"{"files":[]}"#)
            case ("POST", "/drive/v3/files"): .json(#"{"id":"MADE"}"#)
            case ("POST", "/upload/drive/v3/files"): .json(Self.file)
            case ("POST", "/drive/v3/files/FILE/permissions"): .json(#"{"id":"anyoneWithLink"}"#)
            default: .empty(404)
            }
        }
        let receipt = try await destination(server, GoogleDriveConfiguration(clientID: "c")).upload(
            folder.payload(Data("PNG".utf8)), to: ["Safari.png"]
        ) { _ in }
        #expect(receipt.link.absoluteString == "https://drive.google.com/file/d/FILE/view?usp=drivesdk")
        #expect(receipt.notice == nil)
        guard case let .googleDrive(updated) = receipt.updatedTarget else {
            Issue.record("the made folder was not kept")
            return
        }
        #expect(updated.createdFolderID == "MADE")
        let made = try #require(server.requests.first { $0.method == "POST" && $0.url.path == "/drive/v3/files" })
        #expect(made.json?["mimeType"] as? String == "application/vnd.google-apps.folder")
        let upload = try #require(server.requests(to: "/upload/drive/v3/files").first)
        #expect(upload.text.contains(#"{"name":"Safari.png","parents":["MADE"]}"#))
        #expect(upload.text.contains("\r\n\r\nPNG\r\n"))
        #expect(server.requests(to: "/drive/v3/files/FILE/permissions").count == 1)
    }

    @Test func aKnownFolderIsUsedAndTheDownloadLinkCopied() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { request in
            request.url.path == "/upload/drive/v3/files" ? .json(Self.file) : .empty(404)
        }
        let configuration = GoogleDriveConfiguration(
            clientID: "c", folderID: "https://drive.google.com/drive/folders/MINE", sharesPublicly: false, linkStyle: .download,
            access: .everything
        )
        let receipt = try await destination(server, configuration)
            .upload(folder.payload(Data("PNG".utf8)), to: ["8d3f", "Safari.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://drive.google.com/uc?id=FILE&export=download")
        #expect(receipt.updatedTarget == nil)
        #expect(server.requests.count == 1)
        // Drive has no paths: the template's folder becomes part of the name.
        #expect(try #require(server.requests.first).text.contains(#"{"name":"8d3f Safari.png","parents":["MINE"]}"#))
    }

    @Test func aBigFileGoesUpInChunksAndResumesAfterAFailure() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let sessionServer = StubServer { request in
            let range = request.header("Content-Range") ?? ""
            switch range {
            case "bytes 0-3/10": return .empty(308, headers: ["Range": "bytes=0-3"])
            case "bytes 4-7/10": return .empty(503)
            case "bytes */10": return .empty(308, headers: ["Range": "bytes=0-5"])
            case "bytes 6-9/10": return .json(Self.file, status: 201)
            default: return .empty(400)
            }
        }
        // Google hands out the session's address; here it is another stub.
        let upload = StubServer { request in
            request.url.path == "/upload/drive/v3/files" && request.method == "POST"
                ? .empty(200, headers: ["Location": sessionServer.baseURL + "/upload/session?upload_id=U"])
                : .empty(404)
        }
        var big = destination(upload, GoogleDriveConfiguration(clientID: "c", createdFolderID: "F", sharesPublicly: false))
        big.multipartLimit = 4
        big.chunkSize = 4
        let payload = try folder.payload(Data("0123456789".utf8), name: "big", fileExtension: "mov", contentType: "video/quicktime")
        let receipt = try await big.upload(payload, to: ["big.mov"]) { _ in }
        #expect(receipt.link.absoluteString == "https://drive.google.com/file/d/FILE/view?usp=drivesdk")
        let opened = try #require(upload.requests(to: "/upload/drive/v3/files").first)
        #expect(opened.header("X-Upload-Content-Length") == "10")
        #expect(opened.header("X-Upload-Content-Type") == "video/quicktime")
        let sent = sessionServer.requests.map { "\($0.header("Content-Range") ?? "") \($0.text)" }
        #expect(sent == ["bytes 0-3/10 0123", "bytes 4-7/10 4567", "bytes */10 ", "bytes 6-9/10 6789"])
    }

    @Test func aDomainThatForbidsPublicLinksStillGetsTheUpload() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let forbidden = #"""
        {"error": {"code": 403, "message": "The user does not have sufficient permissions for this file.",
                   "errors": [{"reason": "publishOutNotPermitted"}]}}
        """#
        let server = StubServer { request in
            switch request.url.path {
            case "/upload/drive/v3/files": .json(Self.file)
            case "/drive/v3/files/FILE/permissions": .json(forbidden, status: 403)
            default: .empty(404)
            }
        }
        let receipt = try await destination(server, GoogleDriveConfiguration(clientID: "c", createdFolderID: "F")).upload(
            folder.payload(Data("PNG".utf8)), to: ["a.png"]
        ) { _ in }
        #expect(receipt.link.absoluteString.contains("/file/d/FILE/"))
        #expect(receipt.notice?.contains("sufficient permissions") == true)
    }

    @Test func errorsSayWhatToDo() {
        func error(_ status: Int, _ reason: String, _ message: String = "") -> UploadError {
            let body = #"{"error":{"code":\#(status),"message":"\#(message)","errors":[{"reason":"\#(reason)"}]}}"#
            return GoogleDriveResponses.error(status: status, body: Data(body.utf8))
        }
        #expect(error(403, "storageQuotaExceeded") == .quotaExceeded("Your Google Drive is full."))
        #expect(error(403, "accessNotConfigured").localizedDescription.contains("Google Drive API is off"))
        #expect(error(404, "notFound").localizedDescription.contains("can't find the folder"))
        #expect(error(401, "authError") == .signInRequired(service: "Google Drive"))
        #expect(error(403, "userRateLimitExceeded") == .rateLimited("Google Drive is limiting requests. Try again in a minute."))
        #expect(error(403, "insufficientFilePermissions", "No.") == .forbidden("No."))
        let about = #"{"user":{"displayName":"Marcus","emailAddress":"m@example.com"}}"#
        #expect(GoogleDriveResponses.accountName(Data(about.utf8)) == "Marcus (m@example.com)")
    }
}
