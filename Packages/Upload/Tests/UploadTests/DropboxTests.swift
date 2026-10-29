import Foundation
import Testing
@testable import Upload

struct DropboxTests {
    @Test func apiArgIsHeaderSafeJSONWithSortedKeys() throws {
        let header = try DropboxAPIArg.header(DropboxRequests.Commit(path: "/Oriel/Caf\u{E9} \u{7F}\u{1F600}/a.png"))
        // The header's escapes are a backslash, "u" and four hex digits: é, DEL, then 😀 as a UTF-16 surrogate pair.
        let escape = "\u{5C}u"
        let path = "/Oriel/Caf\(escape)00e9 \(escape)007f\(escape)d83d\(escape)de00/a.png"
        #expect(header == #"{"autorename":true,"mode":"add","mute":true,"path":""# + path + #"","strict_conflict":false}"#)
        #expect(header.unicodeScalars.allSatisfy { $0.value < 0x7F })
        // Still the same JSON once Dropbox decodes it.
        let decoded = try #require(try JSONSerialization.jsonObject(with: Data(header.utf8)) as? [String: Any])
        #expect(decoded["path"] as? String == "/Oriel/Caf\u{E9} \u{7F}\u{1F600}/a.png")
    }

    @Test func requestsCarryTheTokenAndTheirArguments() throws {
        let requests = DropboxRequests(endpoints: .production, accessToken: "T")
        let upload = try requests.upload(path: "/Oriel/a b.png")
        #expect(upload.url?.absoluteString == "https://content.dropboxapi.com/2/files/upload")
        #expect(upload.httpMethod == "POST")
        #expect(upload.value(forHTTPHeaderField: "Authorization") == "Bearer T")
        #expect(upload.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(upload.value(forHTTPHeaderField: "Dropbox-API-Arg")
            == #"{"autorename":true,"mode":"add","mute":true,"path":"/Oriel/a b.png","strict_conflict":false}"#)

        let start = try requests.startSession()
        #expect(start.url?.path == "/2/files/upload_session/start")
        #expect(start.value(forHTTPHeaderField: "Dropbox-API-Arg") == #"{"close":false}"#)
        let append = try requests.appendSession(DropboxRequests.Cursor(sessionID: "S", offset: 8))
        #expect(append.url?.path == "/2/files/upload_session/append_v2")
        #expect(append.value(forHTTPHeaderField: "Dropbox-API-Arg") == #"{"close":false,"cursor":{"offset":8,"session_id":"S"}}"#)
        let finish = try requests.finishSession(DropboxRequests.Cursor(sessionID: "S", offset: 16), path: "/x.mov")
        #expect(finish.value(forHTTPHeaderField: "Dropbox-API-Arg")
            ==
            #"{"commit":{"autorename":true,"mode":"add","mute":true,"path":"/x.mov","strict_conflict":false},"#
            + #""cursor":{"offset":16,"session_id":"S"}}"#)

        let link = try requests.createSharedLink(path: "/Oriel/a.png")
        #expect(link.url?.absoluteString == "https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings")
        #expect(link.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect((link.httpBody ?? Data()).utf8Text == #"{"path":"/Oriel/a.png"}"#)
        let list = try requests.listSharedLinks(path: "/Oriel/a.png")
        #expect((list.httpBody ?? Data()).utf8Text == #"{"direct_only":true,"path":"/Oriel/a.png"}"#)
        // RPC calls without arguments send no body at all.
        #expect(try requests.currentAccount().httpBody == nil)
        #expect(try requests.revoke().value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test func linkStylesKeepDropboxsOwnParameters() throws {
        let shared = try #require(URL(string: "https://www.dropbox.com/scl/fi/abc123/Safari.png?rlkey=k3y%2B&st=x&dl=0"))
        #expect(DropboxLink.link(shared, style: .raw)
            .absoluteString == "https://www.dropbox.com/scl/fi/abc123/Safari.png?rlkey=k3y%2B&st=x&raw=1")
        #expect(DropboxLink.link(shared, style: .download)
            .absoluteString == "https://www.dropbox.com/scl/fi/abc123/Safari.png?rlkey=k3y%2B&st=x&dl=1")
        #expect(DropboxLink.link(shared, style: .page)
            .absoluteString == "https://www.dropbox.com/scl/fi/abc123/Safari.png?rlkey=k3y%2B&st=x&dl=0")
        let old = try #require(URL(string: "https://www.dropbox.com/s/xyz/a.png"))
        #expect(DropboxLink.link(old, style: .raw).absoluteString == "https://www.dropbox.com/s/xyz/a.png?raw=1")
    }

    @Test func folderPathsAreDropboxPaths() {
        #expect(DropboxConfiguration(folder: "Oriel/").folderPath == "/Oriel")
        #expect(DropboxConfiguration(folder: " / ").folderPath == "")
        #expect(DropboxConfiguration(folder: "/a/../b").folderPath == "/a/b")
    }

    private func destination(
        _ server: StubServer,
        style: DropboxConfiguration.LinkStyle = .raw,
        token: @escaping @Sendable (Bool) -> String = { _ in "T" }
    ) -> DropboxDestination {
        DropboxDestination(
            configuration: DropboxConfiguration(appKey: "key", folder: "/Oriel", linkStyle: style), http: server.http,
            endpoints: server.endpoints
        ) { refresh in token(refresh) }
    }

    @Test func anUploadSendsTheFileThenCopiesItsLink() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { request in
            switch request.url.path {
            case "/2/files/upload": .json(#"{"name":"Safari.png","path_display":"/Oriel/8d3f/Safari.png","id":"id:1"}"#)
            case "/2/sharing/create_shared_link_with_settings": .json(
                    #"{"url":"https://www.dropbox.com/scl/fi/1/Safari.png?rlkey=r&dl=0"}"#
                )
            default: .empty(404)
            }
        }
        let payload = try folder.payload(Data("PNGDATA".utf8))
        let receipt = try await destination(server).upload(payload, to: ["8d3f", "Safari.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://www.dropbox.com/scl/fi/1/Safari.png?rlkey=r&raw=1")
        #expect(receipt.path == ["8d3f", "Safari.png"])
        let upload = try #require(server.requests(to: "/2/files/upload").first)
        #expect(upload.body == Data("PNGDATA".utf8))
        #expect(upload.jsonHeader("Dropbox-API-Arg")?["path"] as? String == "/Oriel/8d3f/Safari.png")
        let share = try #require(server.requests(to: "/2/sharing/create_shared_link_with_settings").first)
        #expect(share.json?["path"] as? String == "/Oriel/8d3f/Safari.png")
    }

    @Test func aLinkThatExistsIsReused() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let exists = #"""
        {"error_summary": "shared_link_already_exists/metadata/..",
         "error": {".tag": "shared_link_already_exists",
                   "shared_link_already_exists": {".tag": "metadata",
                                                  "metadata": {".tag": "file", "url": "https://www.dropbox.com/s/old/a.png?dl=0"}}}}
        """#
        let server = StubServer { request in
            switch request.url.path {
            case "/2/files/upload": .json(#"{"path_display":"/Oriel/a.png"}"#)
            case "/2/sharing/create_shared_link_with_settings": .json(exists, status: 409)
            default: .empty(404)
            }
        }
        let receipt = try await destination(server, style: .page).upload(folder.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://www.dropbox.com/s/old/a.png?dl=0")
        #expect(server.requests(to: "/2/sharing/list_shared_links").isEmpty)

        let bare = #"{"error_summary":"shared_link_already_exists/..","error":{".tag":"shared_link_already_exists"}}"#
        let listing = StubServer { request in
            switch request.url.path {
            case "/2/files/upload": .json(#"{"path_display":"/Oriel/a.png"}"#)
            case "/2/sharing/create_shared_link_with_settings": .json(bare, status: 409)
            case "/2/sharing/list_shared_links": .json(
                    #"{"links":[{"url":"https://www.dropbox.com/s/listed/a.png?dl=0"}],"has_more":false}"#
                )
            default: .empty(404)
            }
        }
        let listed = try await destination(listing, style: .download).upload(folder.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
        #expect(listed.link.absoluteString == "https://www.dropbox.com/s/listed/a.png?dl=1")
    }

    @Test func anExpiredTokenIsRefreshedAndTheRequestSentAgain() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { request in
            guard request.header("Authorization") == "Bearer fresh" else {
                return .json(#"{"error_summary":"expired_access_token/..","error":{".tag":"expired_access_token"}}"#, status: 401)
            }
            return request.url.path == "/2/files/upload"
                ? .json(#"{"path_display":"/Oriel/a.png"}"#)
                : .json(#"{"url":"https://www.dropbox.com/s/1/a.png?dl=0"}"#)
        }
        let receipt = try await destination(server) { $0 ? "fresh" : "stale" }
            .upload(folder.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://www.dropbox.com/s/1/a.png?raw=1")
        #expect(server.requests(to: "/2/files/upload").map { $0.header("Authorization") } == ["Bearer stale", "Bearer fresh"])
    }

    @Test func aBigFileGoesUpInASession() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let server = StubServer { request in
            switch request.url.path {
            case "/2/files/upload_session/start": .json(#"{"session_id":"S1"}"#)
            case "/2/files/upload_session/append_v2": .json("null")
            case "/2/files/upload_session/finish": .json(#"{"path_display":"/Oriel/big.mov"}"#)
            case "/2/sharing/create_shared_link_with_settings": .json(#"{"url":"https://www.dropbox.com/s/b/big.mov?dl=0"}"#)
            default: .empty(404)
            }
        }
        var big = destination(server, style: .download)
        big.singleUploadLimit = 8
        big.chunkSize = 4
        let payload = try folder.payload(Data("0123456789".utf8), name: "big", fileExtension: "mov", contentType: "video/quicktime")
        let receipt = try await big.upload(payload, to: ["big.mov"]) { _ in }
        #expect(receipt.link.absoluteString == "https://www.dropbox.com/s/b/big.mov?dl=1")
        #expect(server.requests(to: "/2/files/upload").isEmpty)
        #expect(server.requests(to: "/2/files/upload_session/start").map(\.text) == ["0123"])
        let append = try #require(server.requests(to: "/2/files/upload_session/append_v2").first)
        #expect(append.text == "4567")
        #expect((append.jsonHeader("Dropbox-API-Arg")?["cursor"] as? [String: Any])?["offset"] as? Int == 4)
        let finish = try #require(server.requests(to: "/2/files/upload_session/finish").first)
        #expect(finish.text == "89")
        let arg = try #require(finish.jsonHeader("Dropbox-API-Arg"))
        #expect((arg["cursor"] as? [String: Any])?["offset"] as? Int == 8)
        #expect((arg["cursor"] as? [String: Any])?["session_id"] as? String == "S1")
        #expect((arg["commit"] as? [String: Any])?["path"] as? String == "/Oriel/big.mov")
    }

    @Test func errorsSayWhatToDo() {
        func error(_ status: Int, _ body: String) -> UploadError {
            DropboxResponses.error(status: status, body: Data(body.utf8), folder: "/Oriel")
        }
        #expect(error(409, #"{"error_summary":"path/insufficient_space/.."}"#) == .quotaExceeded("Your Dropbox is full."))
        #expect(error(409, #"{"error_summary":"path/no_write_permission/.."}"#) == .forbidden("Your Dropbox app can't write to “/Oriel”."))
        #expect(error(401, #"{"error_summary":"invalid_access_token/.."}"#) == .signInRequired(service: "Dropbox"))
        let scope = error(401, #"{"error_summary":"missing_scope/..","error":{".tag":"missing_scope","required_scope":"sharing.write"}}"#)
        #expect(scope.localizedDescription.contains("sharing.write"))
        #expect(error(429, "") == .rateLimited("Dropbox is limiting requests. Try again in a minute."))
        #expect(error(400, "Error in call to API function \"files/upload\": Invalid client_id").localizedDescription.contains("app key"))
        #expect(DropboxResponses
            .correctOffset(
                Data(#"{"error_summary":"incorrect_offset/..","error":{".tag":"incorrect_offset","correct_offset":12}}"#.utf8)
            ) ==
            12)
        #expect(DropboxResponses.accountName(Data(#"{"email":"a@b.c"}"#.utf8)) == "a@b.c")
    }
}
