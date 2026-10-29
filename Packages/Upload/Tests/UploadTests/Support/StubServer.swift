import Foundation
import Synchronization
@testable import Upload

/// A fake HTTP server with a host name of its own, so tests running in parallel never see each other's requests.
/// Every service Oriel talks to can be pointed at it (`endpoints`).
final class StubServer: Sendable {
    typealias Handler = @Sendable (RecordedRequest) -> StubResponse

    let host = "stub-\(UUID().uuidString.lowercased()).test"
    private let state: Mutex<(handler: Handler, requests: [RecordedRequest])>

    init(_ handler: @escaping Handler) {
        state = Mutex((handler, []))
        StubURLProtocol.register(self)
    }

    deinit {
        StubURLProtocol.unregister(host)
    }

    var baseURL: String {
        "https://\(host)"
    }

    /// Dropbox and Google, all at this server.
    var endpoints: UploadEndpoints {
        UploadEndpoints(
            dropboxAuthorize: baseURL + "/oauth2/authorize",
            dropboxAPI: baseURL,
            dropboxContent: baseURL,
            googleAuthorize: baseURL + "/o/oauth2/v2/auth",
            googleToken: baseURL + "/token",
            googleRevoke: baseURL + "/revoke",
            googleAPI: baseURL
        )
    }

    var requests: [RecordedRequest] {
        state.withLock { $0.requests }
    }

    var http: UploadHTTP {
        UploadHTTP(session: StubURLProtocol.makeSession())
    }

    /// The requests to `path`, in order.
    func requests(to path: String) -> [RecordedRequest] {
        requests.filter { $0.url.path == path }
    }

    func respond(to request: RecordedRequest) -> StubResponse {
        state.withLock { state in
            state.requests.append(request)
            return state.handler(request)
        }
    }
}
