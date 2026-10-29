import AppKit
import Foundation
import OrielCore

/// The current desktop picture, for the background tool. Oriel reads it only from where macOS lets an app read
/// without asking: the system's and the user's Pictures folder. A picture in Desktop, Documents, Downloads, iCloud
/// Drive, another app's container, the Photos library or another volume would make macOS ask for access, so it is
/// left alone and the user is told to choose the image instead (an image chosen in an open panel needs no access).
enum DesktopPicture {
    enum Failure: Error, Equatable {
        /// macOS gave no desktop picture (a live or dynamic wallpaper may have none as a file).
        case unavailable
        /// The picture lives where reading it would make macOS ask.
        case protected
        /// The file is not an image Oriel can decode (a video wallpaper, say).
        case unreadable

        var message: String {
            switch self {
            case .unavailable: "macOS doesn’t offer this desktop picture as an image. Choose an image instead."
            case .protected: "Your desktop picture is in a folder macOS protects. Choose it as an image instead."
            case .unreadable: "This desktop picture can’t be read as an image. Choose an image instead."
            }
        }
    }

    /// The desktop picture of `screen` (the main screen when nil), decoded off the main thread.
    static func load(for screen: NSScreen?) async -> Result<CGImage, Failure> {
        guard let screen = screen ?? NSScreen.main, let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return .failure(.unavailable)
        }
        guard isReadableWithoutPrompt(url, home: FileManager.default.homeDirectoryForCurrentUser) else {
            Log.logger("editor").info("The desktop picture is in a protected folder; not reading it")
            return .failure(.protected)
        }
        let image = await Task.detached(priority: .userInitiated) { PictureLoader.load(url) }.value
        return image.map { .success($0) } ?? .failure(.unreadable)
    }

    /// Whether reading `url` can happen without a privacy prompt: files under /System/Library, /Library or the user's
    /// Pictures folder (but not inside a Photos library). Everything else is refused, to be safe.
    nonisolated static func isReadableWithoutPrompt(_ url: URL, home: URL) -> Bool {
        guard url.isFileURL else { return false }
        let path = url.standardizedFileURL.path
        guard !path.contains("/../") else { return false }
        if path.hasPrefix("/System/Library/") || path.hasPrefix("/Library/") {
            return true
        }
        let pictures = home.standardizedFileURL.appending(path: "Pictures", directoryHint: .isDirectory).path + "/"
        return path.hasPrefix(pictures) && !path.lowercased().contains(".photoslibrary")
    }
}
