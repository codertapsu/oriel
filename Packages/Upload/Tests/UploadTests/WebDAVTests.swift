import Foundation
import Testing
@testable import Upload

struct WebDAVTests {
    @Test func addressesAreEncodedPerPartAndFoldersEndInASlash() throws {
        let server = try #require(URL(string: "https://cloud.example.com/remote.php/dav/files/marcus/"))
        #expect(WebDAVRequests.url(server: server, segments: ["Oriel", "a b", "Café#1.png"], isFolder: false)?.absoluteString
            == "https://cloud.example.com/remote.php/dav/files/marcus/Oriel/a%20b/Caf%C3%A9%231.png")
        #expect(WebDAVRequests.url(server: server, segments: ["Oriel"], isFolder: true)?.absoluteString
            == "https://cloud.example.com/remote.php/dav/files/marcus/Oriel/")
        let bare = try #require(URL(string: "https://nas.local:5006"))
        #expect(WebDAVRequests.url(server: bare, segments: [], isFolder: true)?.absoluteString == "https://nas.local:5006/")
    }

    @Test func requestsUseTheirWebDAVMethodsAndHeaders() throws {
        let url = try #require(URL(string: "https://dav.example.com/Oriel/"))
        let propfind = WebDAVRequests.propfind(url)
        #expect(propfind.httpMethod == "PROPFIND")
        #expect(propfind.value(forHTTPHeaderField: "Depth") == "0")
        #expect(propfind.value(forHTTPHeaderField: "Content-Type") == "application/xml; charset=utf-8")
        #expect((propfind.httpBody ?? Data()).utf8Text.contains("<d:resourcetype/>"))
        #expect(WebDAVRequests.mkcol(url).httpMethod == "MKCOL")
        let put = WebDAVRequests.put(url.appending(path: "a.png"), contentType: "image/png", length: 12)
        #expect(put.httpMethod == "PUT")
        #expect(put.value(forHTTPHeaderField: "If-None-Match") == "*")
        #expect(put.value(forHTTPHeaderField: "Content-Type") == "image/png")
        #expect(put.value(forHTTPHeaderField: "Content-Length") == "12")
    }

    @Test func foldersAreMadeOutermostFirst() {
        #expect(WebDAVRequests.foldersToMake(folder: ["Shots", "Oriel"], path: ["8d3f", "a.png"]) == [
            ["Shots"],
            ["Shots", "Oriel"],
            ["Shots", "Oriel", "8d3f"],
        ])
        #expect(WebDAVRequests.foldersToMake(folder: [], path: ["a.png"]).isEmpty)
    }

    @Test func multistatusSaysFolderOrFile() {
        let folder = #"""
        <?xml version="1.0"?><D:multistatus xmlns:D="DAV:"><D:response><D:href>/Oriel/</D:href><D:propstat>
        <D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop><D:status>HTTP/1.1 200 OK</D:status>
        </D:propstat></D:response></D:multistatus>
        """#
        let file = #"<multistatus xmlns="DAV:"><response><propstat><prop><resourcetype/></prop></propstat></response></multistatus>"#
        let other = #"<d:multistatus xmlns:d="DAV:" xmlns:x="urn:x"><d:response><d:propstat><d:prop><x:collection/></d:prop>"#
            + #"</d:propstat></d:response></d:multistatus>"#
        #expect(WebDAVMultistatus.resource(in: Data(folder.utf8)) == .folder)
        #expect(WebDAVMultistatus.resource(in: Data(file.utf8)) == .file)
        #expect(WebDAVMultistatus.resource(in: Data(other.utf8)) == .unknown)
        #expect(WebDAVMultistatus.resource(in: Data("not xml".utf8)) == .unknown)
    }

    @Test func challengesGetTheCredentialOnce() {
        #expect(WebDAVChallenge
            .answer(method: NSURLAuthenticationMethodHTTPBasic, previousFailures: 0, hasCredential: true) == .useCredential)
        #expect(WebDAVChallenge
            .answer(method: NSURLAuthenticationMethodHTTPDigest, previousFailures: 0, hasCredential: true) == .useCredential)
        #expect(WebDAVChallenge.answer(method: NSURLAuthenticationMethodHTTPDigest, previousFailures: 1, hasCredential: true) == .refuse)
        #expect(WebDAVChallenge
            .answer(method: NSURLAuthenticationMethodHTTPBasic, previousFailures: 0, hasCredential: false) == .performDefault)
        #expect(WebDAVChallenge
            .answer(method: NSURLAuthenticationMethodServerTrust, previousFailures: 0, hasCredential: true) == .performDefault)
    }

    private func destination(
        _ server: StubServer,
        folder: String = "Oriel",
        template: String = "https://files.example.com/{path}",
        known: KnownFolders = KnownFolders()
    ) -> WebDAVDestination {
        WebDAVDestination(
            id: UUID(),
            configuration: WebDAVConfiguration(
                serverURL: server.baseURL + "/dav/",
                username: "marcus",
                folder: folder,
                publicURLTemplate: template
            ),
            password: "secret",
            http: server.http,
            knownFolders: known
        )
    }

    @Test func anUploadMakesItsFoldersThenPutsTheFile() async throws {
        let temporary = try TemporaryFolder()
        defer { temporary.remove() }
        let server = StubServer { request in
            switch (request.method, request.url.path) {
            case ("MKCOL", "/dav/Oriel"): .empty(405)
            case ("MKCOL", _): .empty(201)
            case ("PUT", _): .empty(201)
            default: .empty(400)
            }
        }
        let known = KnownFolders()
        let uploader = destination(server, known: known)
        let receipt = try await uploader.upload(temporary.payload(Data("PNG".utf8)), to: ["8d3f", "Safari.png"]) { _ in }
        #expect(receipt.link.absoluteString == "https://files.example.com/8d3f/Safari.png")
        #expect(server.requests.map { "\($0.method) \($0.url.path)" } == [
            "MKCOL /dav/Oriel",
            "MKCOL /dav/Oriel/8d3f",
            "PUT /dav/Oriel/8d3f/Safari.png",
        ])
        #expect(server.requests.last?.body == Data("PNG".utf8))
        #expect(server.requests.last?.header("If-None-Match") == "*")

        // The configured folder is known now; only the new upload's folder is made.
        _ = try await uploader.upload(temporary.payload(Data("PNG".utf8)), to: ["11aa", "Safari.png"]) { _ in }
        #expect(server.requests.dropFirst(3).map { "\($0.method) \($0.url.path)" } == [
            "MKCOL /dav/Oriel/11aa",
            "PUT /dav/Oriel/11aa/Safari.png",
        ])
    }

    @Test func aNameInUseGetsANumberAndTheLinkIsTheFileWithoutATemplate() async throws {
        let temporary = try TemporaryFolder()
        defer { temporary.remove() }
        let server = StubServer { request in
            switch request.method {
            case "PUT": .empty(request.url.lastPathComponent == "Safari.png" ? 412 : 201)
            default: .empty(405)
            }
        }
        let receipt = try await destination(server, template: "").upload(temporary.payload(Data("PNG".utf8)), to: ["Safari.png"]) { _ in }
        #expect(receipt.path == ["Safari 2.png"])
        #expect(receipt.link.absoluteString == server.baseURL + "/dav/Oriel/Safari%202.png")
    }

    @Test func refusalsSayWhatToDo() async throws {
        let temporary = try TemporaryFolder()
        defer { temporary.remove() }
        func failure(_ answer: @escaping @Sendable (RecordedRequest) -> StubResponse) async throws -> UploadError? {
            let server = StubServer(answer)
            do {
                _ = try await destination(server).upload(temporary.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
                return nil
            } catch {
                return UploadError.from(error)
            }
        }
        #expect(try await failure { _ in .empty(401) } == .unauthorized("The server refused the user name or password."))
        #expect(try await failure { $0.method == "PUT" ? .empty(507) : .empty(201) } == .quotaExceeded("The server has no space left."))
        #expect(try await failure { $0.method == "PUT" ? .empty(403) : .empty(201) } ==
            .forbidden("The server doesn't let this account write to “Oriel”."))
        #expect(try await failure { _ in .empty(409) } == .notFound("The server has no folder at that address. Check the server address."))
        #expect(try await failure { _ in .failure(.cannotFindHost) } == .unreachable("Oriel can't find that server. Check the address."))
    }

    @Test func connectionLooksAtTheFolderThenTheServer() async throws {
        let collection = #"<d:multistatus xmlns:d="DAV:"><d:response><d:propstat><d:prop><d:resourcetype><d:collection/>"#
            + #"</d:resourcetype></d:prop></d:propstat></d:response></d:multistatus>"#
        let present = StubServer { _ in
            StubResponse(status: 207, headers: ["Content-Type": "application/xml"], body: Data(collection.utf8))
        }
        #expect(try await destination(present).testConnection() == "Connected. Uploads go to “Oriel”.")
        #expect(present.requests.first?.method == "PROPFIND")
        #expect(present.requests.first?.url.path == "/dav/Oriel")

        let missing = StubServer { request in
            request.url.path.hasSuffix("/Oriel") ? .empty(404) : StubResponse(status: 207, body: Data(collection.utf8))
        }
        #expect(try await destination(missing).testConnection() == "Connected. Oriel makes the folder “Oriel” with the first upload.")

        let notDAV = StubServer { _ in .empty(405) }
        await #expect(throws: UploadError.self) { try await destination(notDAV).testConnection() }
    }
}
