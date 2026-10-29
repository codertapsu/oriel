import Foundation

/// `application/x-www-form-urlencoded` bodies and query strings, encoding everything but RFC 3986's unreserved
/// characters, so `+`, `&`, `=` and `/` in a token or a URI arrive as they were sent.
nonisolated enum FormEncoding {
    static func encode(_ items: [URLQueryItem]) -> String {
        items.map { "\(escape($0.name))=\(escape($0.value ?? ""))" }.joined(separator: "&")
    }

    static func body(_ items: [URLQueryItem]) -> Data {
        Data(encode(items).utf8)
    }

    static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }

    /// The pairs of a form body, decoded; for tests and for reading callbacks.
    static func decode(_ body: Data) -> [String: String] {
        let text = body.utf8Text
        var pairs: [String: String] = [:]
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let value = parts.count > 1 ? (String(parts[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "") : ""
            pairs[name] = value
        }
        return pairs
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
