import Foundation

/// The URLSession the HTTP providers share, plus request building and streaming. Tests hand in a session whose
/// protocol classes answer every request, so no test reaches the network.
///
/// Nothing here logs URLs, headers or bodies: they can carry API keys and user text.
struct HTTPClient: Sendable {
    let session: URLSession

    /// An ephemeral session: no cookies, no cache, and no waiting for connectivity (offline fails at once).
    static func makeDefault() -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForResource = 600
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return HTTPClient(session: URLSession(configuration: configuration))
    }

    /// A request with a JSON body (or none). `custom` headers go last, so they can override Oriel's own.
    static func request(
        _ url: URL,
        method: String = "POST",
        json body: [String: Any]? = nil,
        headers: [String: String] = [:],
        custom: [String: String] = [:],
        timeout: TimeInterval
    ) throws -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: max(1, timeout))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        for (name, value) in custom where !name.trimmingCharacters(in: .whitespaces).isEmpty {
            request.setValue(value, forHTTPHeaderField: name.trimmingCharacters(in: .whitespaces))
        }
        return request
    }

    /// Sends the request and returns the body of a 2xx answer; other statuses throw the mapped failure.
    func data(for request: URLRequest, kind: ProviderKind) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TranslationFailure.badResponse("The server did not answer over HTTP.") }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw HTTPErrorMapper.failure(status: http.statusCode, body: data, response: http, kind: kind)
        }
        return (data, http)
    }

    /// Opens a streaming request. For a 2xx answer it returns the body bytes; for other statuses it reads up to
    /// 64 KB of the body and throws the mapped failure.
    func stream(_ request: URLRequest, kind: ProviderKind) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw TranslationFailure.badResponse("The server did not answer over HTTP.") }
        guard (200 ..< 300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= 65536 {
                    break
                }
            }
            throw HTTPErrorMapper.failure(status: http.statusCode, body: body, response: http, kind: kind)
        }
        return (bytes, http)
    }

    /// Calls `body` with each line of the stream, empty lines included. `body` returns false to stop early.
    static func forEachLine(in bytes: URLSession.AsyncBytes, _ body: (String) throws -> Bool) async throws {
        var splitter = LineSplitter()
        for try await byte in bytes {
            if let line = splitter.push(byte), try !body(line) {
                return
            }
        }
        if let line = splitter.finish() {
            _ = try body(line)
        }
    }

    /// Whether an answer is a JSON document rather than an event stream (a server that ignored `stream: true`).
    static func isJSON(_ response: HTTPURLResponse) -> Bool {
        (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased().contains("application/json")
    }
}
