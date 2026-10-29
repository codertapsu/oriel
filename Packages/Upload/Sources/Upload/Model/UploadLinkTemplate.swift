import Foundation

/// The link to copy for a destination that serves its files from somewhere else, such as a web server in front of a
/// WebDAV, SFTP or shared folder: `https://files.example.com/{path}`, where `{path}` is the uploaded file's path below
/// the destination's folder, each part percent-encoded. A template without `{path}` is a base the path is added to.
public nonisolated enum UploadLinkTemplate {
    public static let token = "{path}"

    /// The link for `path`, or nil when the template is empty or does not make a URL with a scheme and host.
    public static func link(_ template: String, path: [String]) -> URL? {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let encoded = encodedPath(path)
        let text: String = if trimmed.contains(token) {
            trimmed.replacingOccurrences(of: token, with: encoded)
        } else {
            (trimmed.hasSuffix("/") ? trimmed : trimmed + "/") + encoded
        }
        guard let url = URL(string: text), url.scheme != nil, url.host?.isEmpty == false else { return nil }
        return url
    }

    /// Why `template` cannot make links, or nil when it can (or is empty).
    public static func problem(_ template: String) -> String? {
        let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return link(trimmed, path: ["folder", "name.png"]) == nil ? "Enter a full address, such as https://files.example.com/{path}." : nil
    }

    /// Each part percent-encoded (everything but RFC 3986's unreserved characters), joined with `/`.
    public static func encodedPath(_ path: [String]) -> String {
        path.map(encode).joined(separator: "/")
    }

    public static func encode(_ part: String) -> String {
        part.addingPercentEncoding(withAllowedCharacters: unreserved) ?? part
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
