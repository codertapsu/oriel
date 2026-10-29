import Foundation

/// The WebDAV requests Oriel sends (RFC 4918), built as data so tests can check them: `PROPFIND` (depth 0) to test a
/// folder, `MKCOL` for each missing folder, and `PUT` for the file. Folder URLs end in `/`, which spares a redirect on
/// Apache and Nextcloud.
nonisolated enum WebDAVRequests {
    /// Asks for one property, the resource type, which says whether the address is a folder.
    static let propfindBody = #"<?xml version="1.0" encoding="utf-8"?>"#
        + #"<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>"#

    /// `server` followed by `segments`, each percent-encoded; with a trailing `/` for a folder.
    static func url(server: URL, segments: [String], isFolder: Bool) -> URL? {
        guard var components = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if !segments.isEmpty {
            path += "/" + UploadLinkTemplate.encodedPath(segments)
        }
        if isFolder || path.isEmpty {
            path += "/"
        }
        components.percentEncodedPath = path
        return components.url
    }

    static func propfind(_ url: URL) -> URLRequest {
        var request = base(url, method: "PROPFIND")
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(propfindBody.utf8)
        return request
    }

    static func mkcol(_ url: URL) -> URLRequest {
        base(url, method: "MKCOL")
    }

    /// The file's upload. `If-None-Match: *` makes the server refuse (412) rather than replace a file already there.
    static func put(_ url: URL, contentType: String, length: Int64) -> URLRequest {
        var request = base(url, method: "PUT")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        request.setValue("*", forHTTPHeaderField: "If-None-Match")
        return request
    }

    /// The folders to make, outermost first, for a file at `path` below `folder`: `["Oriel"]`, `["Oriel", "3f9c…"]`.
    static func foldersToMake(folder: [String], path: [String]) -> [[String]] {
        let all = folder + path.dropLast()
        return all.indices.map { Array(all[...$0]) }
    }

    private static func base(_ url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = method
        return request
    }
}
