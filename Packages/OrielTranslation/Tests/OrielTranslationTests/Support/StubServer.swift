import Foundation
@testable import OrielTranslation
import Synchronization

/// A fake HTTP server with its own host name, so tests running in parallel never see each other's requests.
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

    var requests: [RecordedRequest] {
        state.withLock { $0.requests }
    }

    var http: HTTPClient {
        HTTPClient(session: StubURLProtocol.session)
    }

    func respond(to request: RecordedRequest) -> StubResponse {
        state.withLock { state in
            state.requests.append(request)
            return state.handler(request)
        }
    }
}
