import Foundation
import Observation
import OrielCore

/// The history window's state: the entries, the search over their recognized text, and the commands for an item
/// (PLAN §10.4, §17).
@Observable
final class HistoryModel {
    private(set) var entries: [HistoryEntry] = []
    var query = ""
    /// OCR is reading captures in the background, so search does not find all of them yet.
    var isIndexing = false
    @ObservationIgnored let store: HistoryStore
    /// Runs a command for an entry (the coordinator loads the image and copies, pins, opens…).
    @ObservationIgnored var perform: ((HistoryCommand, HistoryEntry) -> Void)?
    /// Each entry's folded search fields, kept until the entry changes, so a keystroke folds nothing.
    @ObservationIgnored private var haystacks: [UUID: (entry: HistoryEntry, folded: String)] = [:]
    @ObservationIgnored private let access: ProAccess

    init(store: HistoryStore, access: ProAccess = .shared) {
        self.store = store
        self.access = access
    }

    /// How many captures the history shows without Oriel Pro; it keeps them all either way (PLAN §19).
    static let freeCount = 20

    /// Whether the whole history and its search are open: with Oriel Pro.
    var showsEverything: Bool {
        access.allows(.captureHistory)
    }

    /// The entries that match the search, newest first; without Oriel Pro, the most recent `freeCount`, unsearched.
    var filtered: [HistoryEntry] {
        guard showsEverything else { return Array(entries.prefix(Self.freeCount)) }
        let terms = HistorySearch.terms(in: query)
        guard !terms.isEmpty else { return entries }
        return entries.filter { HistorySearch.matches(haystack(of: $0), terms: terms) }
    }

    /// Captures whose text OCR has not read yet.
    var pendingCount: Int {
        entries.count { !$0.isIndexed }
    }

    func reload() async {
        entries = await store.entries()
        let ids = Set(entries.map(\.id))
        haystacks = haystacks.filter { ids.contains($0.key) }
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

    private func haystack(of entry: HistoryEntry) -> String {
        if let cached = haystacks[entry.id], cached.entry == entry {
            return cached.folded
        }
        let folded = HistorySearch.haystack(of: entry)
        haystacks[entry.id] = (entry, folded)
        return folded
    }
}
