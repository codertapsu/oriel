import UniformTypeIdentifiers

/// Remembers each extension's category and whether a folder with that extension is a package, so a scan asks
/// `UTType` once per extension rather than once per file. One per scanning thread: it is a value type and not shared.
nonisolated struct FileCategoryCache {
    private var categories: [String: FileCategory] = [:]
    private var packages: [String: Bool] = [:]

    /// The extensions macOS shows as single items, checked without a `UTType` lookup.
    static let knownPackages: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "appex", "xpc", "photoslibrary", "musiclibrary", "tvlibrary",
        "aplibrary", "migratedphotolibrary", "fcpbundle", "imovielibrary", "logicx", "band", "xcarchive", "xcodeproj",
        "xcworkspace", "playground", "rtfd", "pages", "numbers", "key", "sparsebundle", "pkg", "mpkg", "dsym",
        "scptd", "wdgt", "saver", "prefpane", "qlgenerator", "mdimporter", "component", "vst", "vst3",
    ]

    mutating func category(of name: String) -> FileCategory {
        if let known = FileCategory.wellKnownNames[name] {
            return known
        }
        guard let ext = FileCategory.fileExtension(of: name) else { return .other }
        if let known = categories[ext] {
            return known
        }
        let category = FileCategory.of(extension: ext)
        categories[ext] = category
        return category
    }

    /// Whether a folder named `name` is a package (an app, a library, a document bundle).
    mutating func isPackage(_ name: String) -> Bool {
        guard let ext = FileCategory.fileExtension(of: name) else { return false }
        if Self.knownPackages.contains(ext) {
            return true
        }
        if let known = packages[ext] {
            return known
        }
        // An undeclared extension gets a dynamic type that conforms to nothing but data, so it is never a package.
        let isPackage = UTType(filenameExtension: ext)?.conforms(to: .package) == true
        packages[ext] = isPackage
        return isPackage
    }
}
