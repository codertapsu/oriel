import AppKit

/// The places in System Settings and Finder that Disk Space Analyzer sends the user to. The anchors were read from the
/// macOS 27.0.1 Settings extensions (`Privacy_AllFiles` in Privacy & Security; `com.apple.settings.Storage`).
enum SystemLinks {
    /// Privacy & Security → Full Disk Access.
    static let fullDiskAccess = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    /// General → Storage.
    static let storageSettings = URL(string: "x-apple.systempreferences:com.apple.settings.Storage")

    static func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the Trash in Finder; emptying it is the user's choice there.
    static func openTrash() {
        let trash = (try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/.Trash", isDirectory: true)
        NSWorkspace.shared.open(trash)
    }

    static func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
