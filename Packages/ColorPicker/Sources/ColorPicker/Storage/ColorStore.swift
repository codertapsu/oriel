import Foundation
import OrielCore
import os

/// The library on disk, `library.json` (`ColorLibraryFile`), read once when the module starts and written after each
/// change. An actor, so file IO stays off the main thread. Every save carries a revision, and an older revision never
/// overwrites a newer one, whatever order their tasks run in.
actor ColorStore {
    static let fileName = "library.json"

    nonisolated let directory: URL
    /// Set when the file was written by a newer Oriel: it is left as it is, and nothing is saved over it.
    private(set) var isReadOnly = false
    private var savedRevision = 0
    private let log = Log.logger("color-picker")

    init(directory: URL) {
        self.directory = directory
    }

    nonisolated var fileURL: URL {
        directory.appending(path: Self.fileName)
    }

    /// Reads the library; an empty one when there is no file yet. A file that cannot be read is moved aside, next to
    /// it, so it is not lost and the library starts afresh; a newer Oriel's file is kept and this session saves nothing.
    func load() -> ColorLibrary {
        guard let data = try? Data(contentsOf: fileURL) else { return ColorLibrary() }
        do {
            return try ColorLibraryFile.decode(data)
        } catch let ColorLibraryFile.ReadError.newerVersion(version) {
            isReadOnly = true
            log.error("library.json is version \(version, privacy: .public), newer than this Oriel reads; it is left alone")
            return ColorLibrary()
        } catch {
            let aside = directory.appending(path: "library-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            log.error("library.json could not be read and was moved aside: \(error.localizedDescription, privacy: .public)")
            return ColorLibrary()
        }
    }

    /// Writes `library` atomically, unless a later revision is already saved or the file belongs to a newer Oriel.
    func save(_ library: ColorLibrary, revision: Int) throws {
        guard !isReadOnly, revision > savedRevision else { return }
        try AppPaths.ensureDirectory(directory)
        try ColorLibraryFile.encode(library).write(to: fileURL, options: .atomic)
        savedRevision = revision
    }
}
