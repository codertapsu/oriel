import UniformTypeIdentifiers

/// What kind of content a file is, for the File Types breakdown, the filters and the chart colors. Files inside a
/// package take the package's category, so an app's thousands of files count as one application.
nonisolated enum FileCategory: UInt8, CaseIterable, Sendable, Codable, Comparable {
    case video, audio, image, document, archive, diskImage, application, code, other

    static func < (lhs: FileCategory, rhs: FileCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .video: "Videos"
        case .audio: "Audio"
        case .image: "Pictures"
        case .document: "Documents"
        case .archive: "Archives"
        case .diskImage: "Disk images"
        case .application: "Apps"
        case .code: "Developer files"
        case .other: "Other"
        }
    }

    /// An SF Symbol.
    var symbol: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        case .document: "doc.text"
        case .archive: "archivebox"
        case .diskImage: "opticaldiscdrive"
        case .application: "app.badge"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .other: "doc"
        }
    }

    /// The category of a file named `name`, from its extension: a table for the common ones, then the extension's
    /// `UTType`. Callers on hot paths keep a `FileCategoryCache` instead.
    static func of(name: String) -> FileCategory {
        if let known = wellKnownNames[name] {
            return known
        }
        guard let ext = fileExtension(of: name) else { return .other }
        return of(extension: ext)
    }

    /// Big files whose extension says the wrong thing: Docker's disk image is a `.raw`, which is also camera RAW.
    static let wellKnownNames: [String: FileCategory] = ["Docker.raw": .diskImage, "Docker.qcow2": .diskImage]

    static func of(extension ext: String) -> FileCategory {
        if let known = table[ext] {
            return known
        }
        guard let type = UTType(filenameExtension: ext) else { return .other }
        return of(type: type)
    }

    static func of(type: UTType) -> FileCategory {
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        if type.conforms(to: .audio) {
            return .audio
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .diskImage) {
            return .diskImage
        }
        if type.conforms(to: .archive) {
            return .archive
        }
        if type.conforms(to: .application) || type.conforms(to: .executable) {
            return .application
        }
        if type.conforms(to: .sourceCode) || type.conforms(to: .script) {
            return .code
        }
        let documents: [UTType] = [.text, .pdf, .presentation, .spreadsheet, .epub]
        return documents.contains(where: type.conforms(to:)) ? .document : .other
    }

    /// The lowercased extension of `name`, without the dot; nil for names without one and for dot files (".zshrc").
    static func fileExtension(of name: String) -> String? {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        let ext = name[name.index(after: dot)...]
        guard !ext.isEmpty, ext.count <= 16 else { return nil }
        return ext.lowercased()
    }

    /// The common extensions, so most files never need a `UTType` lookup.
    private static let table: [String: FileCategory] = {
        var table: [String: FileCategory] = [:]
        let groups: [(FileCategory, [String])] = [
            (.video, [
                "mp4", "m4v", "mov", "mkv", "avi", "wmv", "webm", "mts", "m2ts", "mpg", "mpeg", "3gp", "hevc", "prores",
                "fcpbundle", "imovielibrary", "tvlibrary",
            ]),
            (.audio, [
                "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "ogg", "opus", "caf", "alac", "m4b", "m4p", "musiclibrary",
                "logicx", "band",
            ]),
            (.image, [
                "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp", "svg", "psd", "dng",
                "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "exr", "icns", "ico", "avif", "photoslibrary",
                "migratedphotolibrary", "aplibrary",
            ]),
            (.document, [
                "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "rtfd", "md",
                "epub", "csv", "odt", "ods", "odp",
            ]),
            (.archive, ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "lz4", "xip", "cpio", "jar", "zipx"]),
            (.diskImage, ["dmg", "iso", "img", "sparseimage", "sparsebundle", "vmdk", "vdi", "qcow2", "vhd", "vhdx", "toast", "ipsw"]),
            (.application, [
                "app", "pkg", "mpkg", "appex", "ipa", "exe", "msi", "apk", "xpc", "plugin", "kext", "prefpane", "saver",
                "qlgenerator", "mdimporter", "component", "vst", "vst3", "wdgt",
            ]),
            (.code, [
                "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "js", "mjs", "cjs", "ts", "tsx", "jsx", "py", "rb", "go",
                "rs", "java", "kt", "json", "yaml", "yml", "xml", "html", "css", "scss", "sh", "o", "a", "dylib",
                "swiftmodule", "dsym", "xcarchive", "pch", "map", "wasm", "class", "lock", "framework", "xcodeproj",
                "xcworkspace", "playground",
            ]),
            // Extensions whose UTType says the wrong thing for what they hold now: macOS takes `.bin` for MacBinary, an
            // archive, but it is firmware, model weights or any binary data.
            (.other, ["bin"]),
        ]
        for (category, extensions) in groups {
            for ext in extensions {
                table[ext] = category
            }
        }
        return table
    }()
}
