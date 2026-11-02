import Foundation
import Synchronization

/// A folder the user chose, kept as a security-scoped bookmark, so that the App Store edition's sandbox lets Oriel back
/// in after a relaunch (PLAN §19); in the sandbox a path alone opens nothing.
public enum FolderBookmark {
    /// The folders whose access has started. Access lasts as long as Oriel runs, and each start holds another of the
    /// kernel's sandbox extensions, so a folder is started once.
    private static let started = Mutex<Set<String>>([])

    public static func make(for url: URL) -> Data? {
        try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The folder, with access started for as long as Oriel runs; nil when it is gone or the bookmark no longer opens.
    public static func resolve(_ data: Data) -> URL? {
        var isStale = false
        let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        guard let url, startAccessing(url) else { return nil }
        return url
    }

    /// Starts access to a folder resolved from a security-scoped bookmark, once per launch.
    @discardableResult
    public static func startAccessing(_ url: URL) -> Bool {
        started.withLock { started in
            guard !started.contains(url.path) else { return true }
            guard url.startAccessingSecurityScopedResource() else { return false }
            started.insert(url.path)
            return true
        }
    }
}
