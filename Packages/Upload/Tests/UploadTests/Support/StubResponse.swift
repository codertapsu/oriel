import Foundation

/// A canned answer.
struct StubResponse: Sendable {
    var status = 200
    var headers: [String: String] = [:]
    var body = Data()
    var error: URLError?

    static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: ["Content-Type": "application/json"].merging(headers) { $1 }, body: Data(text.utf8))
    }

    static func text(_ text: String, status: Int, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: ["Content-Type": "text/plain"].merging(headers) { $1 }, body: Data(text.utf8))
    }

    static func empty(_ status: Int, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: headers)
    }

    static func failure(_ code: URLError.Code) -> StubResponse {
        StubResponse(error: URLError(code))
    }
}
