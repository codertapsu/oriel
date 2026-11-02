import Foundation
import OrielCore

/// Finding and checking a shared folder. Outside the sandbox the bookmark is a plain one: it finds the folder after a
/// rename or move; in the App Store edition it is security-scoped, which the sandbox needs to let Oriel back in. It is
/// resolved without UI and without mounting, so an upload never stops at a server's password dialog; an unmounted share
/// says so instead.
nonisolated enum SharedFolderAccess {
    /// Security-scoped in the App Store edition, whose sandbox opens a folder after a relaunch only through one.
    static func bookmark(for folder: URL) throws -> Data {
        try folder.bookmarkData(options: Sandbox.isActive ? .withSecurityScope : [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The folder now, and the settings to keep when its bookmark had to be renewed (it moved, or it had none).
    static func resolve(_ configuration: SharedFolderConfiguration) -> (folder: URL, updated: SharedFolderConfiguration?) {
        let byPath = URL(fileURLWithPath: configuration.path, isDirectory: true)
        guard let bookmark = configuration.bookmark else {
            return (byPath, nil)
        }
        var isStale = false
        let scope: URL.BookmarkResolutionOptions = Sandbox.isActive ? .withSecurityScope : []
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting, scope], relativeTo: nil, bookmarkDataIsStale: &isStale
        ) else {
            return (byPath, nil)
        }
        if Sandbox.isActive {
            FolderBookmark.startAccessing(resolved)
        }
        guard isStale || resolved.path != configuration.path, let renewed = try? Self.bookmark(for: resolved) else {
            return (resolved, nil)
        }
        var updated = configuration
        updated.path = resolved.path
        updated.bookmark = renewed
        return (resolved, updated)
    }

    /// Throws unless `folder` is a folder Oriel can write into.
    static func check(_ folder: URL, displayPath: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) else {
            let volume = folder.pathComponents.count > 2 && folder.pathComponents[1] == "Volumes" ? folder.pathComponents[2] : nil
            if let volume {
                throw UploadError.notFound("“\(volume)” isn't connected. Connect to it in Finder, then try again.")
            }
            throw UploadError.notFound("The folder \(displayPath) isn't there any more. Choose it again in Settings → Upload.")
        }
        guard isDirectory.boolValue else {
            throw UploadError.invalidSettings("\(displayPath) is a file, not a folder.")
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UploadError.forbidden("Oriel can't write into \(displayPath).")
        }
    }

    /// The `smb://server/share/…` address of a file on a mounted network share, for the people who can open that share
    /// themselves; nil for a local disk. The user name the share was mounted with is left out.
    static func networkLink(for file: URL) -> URL? {
        guard let values = try? file.resourceValues(forKeys: [.volumeIsLocalKey, .volumeURLForRemountingKey, .volumeURLKey]),
              values.volumeIsLocal == false,
              let remount = values.volumeURLForRemounting,
              let volume = values.volume,
              var components = URLComponents(url: remount, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        components.user = nil
        components.password = nil
        let volumeParts = volume.standardizedFileURL.pathComponents
        let fileParts = file.standardizedFileURL.pathComponents
        guard fileParts.starts(with: volumeParts) else { return nil }
        let relative = Array(fileParts.dropFirst(volumeParts.count))
        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        components.percentEncodedPath = path + "/" + UploadLinkTemplate.encodedPath(relative)
        return components.url
    }
}
