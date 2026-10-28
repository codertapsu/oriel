import AppKit
import Observation
import OrielCore

/// The history window's state: the saved entries, their thumbnails, and the history settings.
@MainActor
@Observable
final class TranslationHistoryModel {
    private let store: TranslationHistoryStore
    private let settings: SettingsStore
    private(set) var entries: [TranslationHistoryEntry] = []
    private(set) var thumbnails: [UUID: NSImage] = [:]
    var selection: UUID?

    init(store: TranslationHistoryStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    var isEnabled: Bool {
        get { settings[TranslationKeys.historyEnabled] }
        set { settings[TranslationKeys.historyEnabled] = newValue }
    }

    var selectedEntry: TranslationHistoryEntry? {
        entries.first { $0.id == selection }
    }

    /// Purges expired entries, then reads the rest and their thumbnails.
    func reload() async {
        let retention = settings[TranslationKeys.historyRetentionDays]
        _ = try? await store.purge(olderThanDays: retention)
        entries = await store.entries()
        for entry in entries where thumbnails[entry.id] == nil {
            if let data = await store.thumbnailData(for: entry.id), let image = NSImage(data: data) {
                thumbnails[entry.id] = image
            }
        }
        if let selection, !entries.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }

    func delete(_ id: UUID) async {
        try? await store.delete(id)
        thumbnails[id] = nil
        await reload()
    }

    func deleteAll() async {
        try? await store.deleteAll()
        thumbnails = [:]
        await reload()
    }
}
