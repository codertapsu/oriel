import Foundation

/// A canned answer, delivered in chunks so streaming parsers see arbitrary packet boundaries.
struct StubResponse: Sendable {
    var status = 200
    var headers: [String: String] = ["Content-Type": "application/json"]
    var chunks: [Data] = []
    var error: URLError?

    static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: ["Content-Type": "application/json"].merging(headers) { $1 }, chunks: [Data(text.utf8)])
    }

    /// An event stream split into pieces of `chunkSize` bytes, regardless of line or character boundaries.
    static func events(_ text: String, chunkSize: Int = 7) -> StubResponse {
        let bytes = Array(text.utf8)
        let chunks = stride(from: 0, to: bytes.count, by: chunkSize).map { Data(bytes[$0 ..< min($0 + chunkSize, bytes.count)]) }
        return StubResponse(status: 200, headers: ["Content-Type": "text/event-stream"], chunks: chunks)
    }

    static func failure(_ code: URLError.Code) -> StubResponse {
        StubResponse(error: URLError(code))
    }
}
