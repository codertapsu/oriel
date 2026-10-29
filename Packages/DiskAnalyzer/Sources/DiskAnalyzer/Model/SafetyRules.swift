import Foundation

/// What Oriel refuses to move to the Trash, delete or move, whatever the user selects: macOS itself, the tops of
/// volumes, the home folder and its own folders, the Library folders apps rely on, the tops of cloud storage, anything
/// inside an app or other package (remove the whole item instead), and Oriel. Pure, so every rule is tested.
nonisolated struct SafetyRules: Sendable {
    enum Refusal: Equatable, Sendable {
        case volumeRoot
        case system
        case systemApp
        case homeFolder
        case homeTopLevel
        case userFolder
        case libraryFolder
        case cloudRoot
        case insidePackage(String)
        case oriel

        var message: String {
            switch self {
            case .volumeRoot: "It is the top of a volume."
            case .system: "It is part of macOS."
            case .systemApp: "It is an app that comes with macOS."
            case .homeFolder: "It is your home folder."
            case .homeTopLevel: "It is one of your home folder's own folders. Remove what is inside it instead."
            case .userFolder: "It is a user's home folder."
            case .libraryFolder: "It is a Library folder that apps rely on. Remove what is inside it instead."
            case .cloudRoot: "It is the top of a cloud storage location."
            case let .insidePackage(name): "It is inside “\(name)”. Remove the whole item instead."
            case .oriel: "It is Oriel itself."
            }
        }
    }

    var home: String
    /// Mount points: `/`, `/Volumes/…`, `/System/Volumes/Data`.
    var volumeRoots: Set<String>
    /// Oriel's own app bundle.
    var appBundle: String?
    var firmlinks: FirmlinkMap = .empty
    /// The user's own temporary folder (`NSTemporaryDirectory()`, inside /private/var/folders): what is in it is
    /// theirs to remove, unlike the rest of /private/var.
    var temporaryFolder: String?

    /// Folders at the top of the startup volume that macOS owns; they and their contents are refused, except as
    /// `allowedInside` says.
    private static let systemRoots: Set<String> = [
        "/System", "/bin", "/sbin", "/usr", "/private", "/dev", "/etc", "/var", "/tmp", "/cores", "/Network", "/home", "/net",
    ]
    /// Folders macOS owns whose contents are the user's to manage.
    private static let allowedInside = ["/usr/local/", "/private/tmp/", "/tmp/"]
    /// Folders at the top that are refused themselves, with their direct children, but not deeper contents. Directly in
    /// /Applications only apps are allowed, and in /Users nothing.
    private static let guardedFolders: Set<String> = ["/Applications", "/Library", "/Users", "/Volumes", "/opt"]

    /// Why `path` must not be removed or moved, or nil if it may be. `isFolder` tells a folder directly in the home
    /// folder (refused) from a file there (allowed); `symlinkDestination` is where a symbolic link points, which is
    /// never followed, but an app in /Applications that points into macOS is refused.
    func refusal(for path: String, isFolder: Bool, symlinkDestination: String? = nil) -> Refusal? {
        let path = firmlinks.visiblePath(for: ExclusionRules.normalize(path, home: home))
        if path == "/" || volumeRoots.contains(path) || volumeRoots.contains(firmlinks.dataPath(for: path)) {
            return .volumeRoot
        }
        if let appBundle, path == appBundle || path.hasPrefix(appBundle + "/") {
            return .oriel
        }
        if !isInsideTemporaryFolder(path), let refusal = systemRefusal(for: path, symlinkDestination: symlinkDestination) {
            return refusal
        }
        if let refusal = homeRefusal(for: path, isFolder: isFolder) {
            return refusal
        }
        if let package = enclosingPackage(of: path) {
            return .insidePackage(package)
        }
        return nil
    }

    /// Whether `path` is inside the user's temporary folder (not the folder itself), in either spelling of /private.
    private func isInsideTemporaryFolder(_ path: String) -> Bool {
        guard let temporaryFolder else { return false }
        let folder = ExclusionRules.normalize(temporaryFolder, home: home)
        let spellings = folder.hasPrefix("/private/") ? [folder, String(folder.dropFirst(8))] : [folder, "/private" + folder]
        return spellings.contains { path.hasPrefix($0 + "/") }
    }

    private func systemRefusal(for path: String, symlinkDestination: String?) -> Refusal? {
        if path.hasPrefix(FirmlinkMap.dataVolume + "/") {
            // On the data volume, outside the firmlinks: Spotlight's index, the file-system event log and the like.
            return .system
        }
        let first = "/" + (path.split(separator: "/").first.map(String.init) ?? "")
        if Self.systemRoots.contains(first), !Self.allowedInside.contains(where: { path.hasPrefix($0) }) {
            return .system
        }
        if Self.guardedFolders.contains(path) {
            return .system
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard Self.guardedFolders.contains(parent) else { return nil }
        switch parent {
        case "/Users":
            return path == home ? .homeFolder : .userFolder
        case "/Applications":
            if let symlinkDestination, Self.pointsIntoSystem(symlinkDestination, from: parent) {
                return .systemApp
            }
            // An app the user installed is theirs to remove; the folders macOS and installers keep apps in are not.
            return path.hasSuffix(".app") ? nil : .system
        default:
            return .system
        }
    }

    private func homeRefusal(for path: String, isFolder: Bool) -> Refusal? {
        if path == home {
            return .homeFolder
        }
        let parent = (path as NSString).deletingLastPathComponent
        if parent == home, isFolder {
            return .homeTopLevel
        }
        let library = home + "/Library"
        if parent == library {
            return .libraryFolder
        }
        if parent == library + "/Mobile Documents" || parent == library + "/CloudStorage" {
            return .cloudRoot
        }
        return nil
    }

    /// The outermost package (an app, a library, a document bundle) strictly above `path`, by name.
    private func enclosingPackage(of path: String) -> String? {
        let components = path.split(separator: "/").dropLast()
        for component in components {
            if let ext = FileCategory.fileExtension(of: String(component)), FileCategoryCache.knownPackages.contains(ext) {
                return String(component)
            }
        }
        return nil
    }

    private static func pointsIntoSystem(_ destination: String, from folder: String) -> Bool {
        let absolute = destination.hasPrefix("/") ? destination : folder + "/" + destination
        return ExclusionRules.normalize(absolute, home: "").hasPrefix("/System/")
    }
}
