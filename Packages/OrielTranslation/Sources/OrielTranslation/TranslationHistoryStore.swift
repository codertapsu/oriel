import CoreGraphics
import Foundation

/// Translation history on disk (PLAN §7.7.6): one folder per entry, `<directory>/<uuid>/entry.json` and
/// `thumbnail.png`. Opt-in; the coordinator only writes here when history is on. Old entries are purged when an entry
/// is added or the history opens, never on a timer.
actor TranslationHistoryStore {
    private let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL) {
        self.directory = directory
    }

    func add(_ entry: TranslationHistoryEntry, image: CGImage?) throws {
        let folder = directory.appending(path: entry.id.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entry).write(to: folder.appending(path: "entry.json"), options: .atomic)
        if let image, let thumbnail = ImageEncoder.pngThumbnail(image) {
            try thumbnail.write(to: folder.appending(path: "thumbnail.png"), options: .atomic)
        }
    }

    /// Every entry, newest first. Unreadable folders are skipped.
    func entries() -> [TranslationHistoryEntry] {
        guard let folders = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appending(path: "entry.json")) else { return nil }
            return try? decoder.decode(TranslationHistoryEntry.self, from: data)
        }
        .sorted { $0.date > $1.date }
    }

    func thumbnailData(for id: UUID) -> Data? {
        try? Data(contentsOf: directory.appending(path: id.uuidString, directoryHint: .isDirectory).appending(path: "thumbnail.png"))
    }

    func delete(_ id: UUID) throws {
        let folder = directory.appending(path: id.uuidString, directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: folder.path) else { return }
        try fileManager.removeItem(at: folder)
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    /// Deletes entries older than `days` (0 keeps everything) and returns how many went.
    @discardableResult
    func purge(olderThanDays days: Int, now: Date = Date()) throws -> Int {
        guard days > 0 else { return 0 }
        let cutoff = now.addingTimeInterval(-Double(days) * 86400)
        let expired = entries().filter { $0.date < cutoff }
        for entry in expired {
            try delete(entry.id)
        }
        return expired.count
    }
}
