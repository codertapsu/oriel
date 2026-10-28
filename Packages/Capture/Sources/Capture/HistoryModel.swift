import Foundation
import Observation

/// The history window's state: the entries, the search over their recognized text, and the commands for an item
/// (PLAN §10.4).
@Observable
final class HistoryModel {
    private(set) var entries: [HistoryEntry] = []
    var query = ""
    /// OCR is reading captures in the background, so search does not find all of them yet.
    var isIndexing = false
    @ObservationIgnored let store: HistoryStore
    /// Runs a command for an entry (the coordinator loads the image and copies, pins, opens…).
    @ObservationIgnored var perform: ((HistoryCommand, HistoryEntry) -> Void)?

    init(store: HistoryStore) {
        self.store = store
    }

    var filtered: [HistoryEntry] {
        HistorySearch.filter(entries, query: query)
    }

    func reload() async {
        entries = await store.entries()
    }

    func thumbnailURL(for entry: HistoryEntry) -> URL {
        store.thumbnailURL(for: entry)
    }

    func imageURL(for entry: HistoryEntry) -> URL {
        store.imageURL(for: entry)
    }

    func delete(_ entry: HistoryEntry) async {
        try? await store.remove([entry.id])
        await reload()
    }

    func clear() async {
        try? await store.removeAll()
        await reload()
    }
}
