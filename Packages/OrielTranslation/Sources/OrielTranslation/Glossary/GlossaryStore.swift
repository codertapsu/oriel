import Foundation
import OrielCore

/// Glossaries on disk: one JSON file, `~/Library/Application Support/Oriel/Glossaries/glossaries.json`, written
/// atomically and only when something changed. An actor, so reading and writing never happen on the main thread.
actor GlossaryStore {
    static var defaultFile: URL {
        AppPaths.applicationSupport.appending(path: "Glossaries", directoryHint: .isDirectory).appending(path: "glossaries.json")
    }

    let file: URL

    init(file: URL) {
        self.file = file
    }

    /// The saved library, or nil when there is no file yet.
    func load() throws -> GlossaryLibrary? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode(GlossaryLibrary.self, from: data)
    }

    func save(_ library: GlossaryLibrary) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(library).write(to: file, options: .atomic)
    }

    /// Moves an unreadable file aside (`glossaries.unreadable-<date>.json`), so a fresh library can be saved without
    /// destroying what the user had.
    func setAsideUnreadable() throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let aside = file.deletingLastPathComponent().appending(path: "glossaries.unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: file, to: aside)
    }
}
