import Foundation

/// Builds request URLs from the endpoint a user typed, which may or may not end in `/v1` or a full path.
enum Endpoint {
    /// `base` joined with `path`. An API root without a path gets `versionPrefix` (`v1`); a base that already ends
    /// with `path` (someone pasted the full URL) is used as is. Nil for anything that is not an http(s) URL.
    static func url(_ base: String, path: String, versionPrefix: String? = nil) -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty
        else {
            return nil
        }
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var existing = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if existing.hasSuffix(normalizedPath), !normalizedPath.isEmpty {
            existing.removeLast(normalizedPath.count)
            existing = existing.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if existing.isEmpty, let versionPrefix {
            existing = versionPrefix
        }
        components.path = "/" + [existing, normalizedPath].filter { !$0.isEmpty }.joined(separator: "/")
        return components.url
    }

    /// Whether requests to `base` stay on this Mac, so they work offline (Ollama, LM Studio and llama.cpp on
    /// localhost).
    static func isLocal(_ base: String) -> Bool {
        guard let host = URLComponents(string: base.trimmingCharacters(in: .whitespaces))?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]" || host.hasSuffix(".localhost")
    }
}
