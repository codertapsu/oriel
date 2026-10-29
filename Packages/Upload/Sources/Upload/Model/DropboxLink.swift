import Foundation

/// The forms of a Dropbox shared link. Dropbox's own query items stay (newer links need `rlkey` to open); only `dl`
/// and `raw` change: `dl=0` opens Dropbox's page, `raw=1` the file itself, `dl=1` a download.
nonisolated enum DropboxLink {
    static func link(_ shared: URL, style: DropboxConfiguration.LinkStyle) -> URL {
        guard var components = URLComponents(url: shared, resolvingAgainstBaseURL: false) else { return shared }
        var items = (components.percentEncodedQueryItems ?? []).filter { $0.name != "dl" && $0.name != "raw" }
        switch style {
        case .page: items.append(URLQueryItem(name: "dl", value: "0"))
        case .raw: items.append(URLQueryItem(name: "raw", value: "1"))
        case .download: items.append(URLQueryItem(name: "dl", value: "1"))
        }
        components.percentEncodedQueryItems = items
        return components.url ?? shared
    }
}
