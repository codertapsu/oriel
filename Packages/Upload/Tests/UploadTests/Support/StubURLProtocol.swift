import Foundation
import Synchronization

/// Answers every request of a stub session from the `StubServer` registered for its host; an unknown host fails as
/// if nothing were there. No request ever leaves the process.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let servers = Mutex<[String: StubServer]>([:])

    /// A new session that only this protocol answers. `UploadService` invalidates each session it is given, so every
    /// operation gets its own.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func register(_ server: StubServer) {
        servers.withLock { $0[server.host] = server }
    }

    static func unregister(_ host: String) {
        _ = servers.withLock { $0.removeValue(forKey: host) }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let server = Self.servers.withLock({ $0[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let recorded = RecordedRequest(
            method: request.httpMethod ?? "GET", url: url, headers: request.allHTTPHeaderFields ?? [:], body: Self.body(of: request)
        )
        let answer = server.respond(to: recorded)
        if let error = answer.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: answer.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands protocols an upload's body as a stream.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
