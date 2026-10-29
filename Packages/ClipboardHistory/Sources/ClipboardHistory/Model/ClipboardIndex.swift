import Foundation

/// The list Clipboard History keeps: pinned items in the order the user gave them, then the history, newest first
/// unless the user moved something. Pure, so every rule is tested without files; `ClipboardStore` saves it.
nonisolated struct ClipboardIndex: Codable, Sendable, Equatable {
    /// Where an item was, so Undo can put it back.
    struct Position: Codable, Sendable, Equatable {
        let section: ClipboardSection
        let index: Int
    }

    /// An item taken out, with where it was.
    struct Removal: Codable, Sendable, Equatable {
        let item: ClipboardItem
        let position: Position
    }

    var pinned: [ClipboardItem] = []
    var history: [ClipboardItem] = []

    var all: [ClipboardItem] {
        pinned + history
    }

    var count: Int {
        pinned.count + history.count
    }

    func item(_ id: UUID) -> ClipboardItem? {
        pinned.first { $0.id == id } ?? history.first { $0.id == id }
    }

    func position(of id: UUID) -> Position? {
        if let index = pinned.firstIndex(where: { $0.id == id }) {
            return Position(section: .pinned, index: index)
        }
        if let index = history.firstIndex(where: { $0.id == id }) {
            return Position(section: .history, index: index)
        }
        return nil
    }

    func items(in section: ClipboardSection) -> [ClipboardItem] {
        section == .pinned ? pinned : history
    }

    /// Keeps a copy. A copy of something already kept updates that item instead and returns it: in the history it moves
    /// to the top, while a pinned item stays where the user put it.
    @discardableResult
    mutating func record(_ copy: ClipboardItem) -> (item: ClipboardItem, isNew: Bool) {
        if let index = pinned.firstIndex(where: { $0.contentHash == copy.contentHash }) {
            pinned[index].absorb(copy)
            return (pinned[index], false)
        }
        if let index = history.firstIndex(where: { $0.contentHash == copy.contentHash }) {
            var existing = history.remove(at: index)
            existing.absorb(copy)
            history.insert(existing, at: 0)
            return (existing, false)
        }
        history.insert(copy, at: 0)
        return (copy, true)
    }

    /// An item was just pasted or copied, so it is what the clipboard holds again: it gets today's date and, in the
    /// history, moves to the top.
    mutating func touch(_ id: UUID, at date: Date) {
        if let index = pinned.firstIndex(where: { $0.id == id }) {
            pinned[index].lastCopied = date
        } else if let index = history.firstIndex(where: { $0.id == id }) {
            var item = history.remove(at: index)
            item.lastCopied = date
            history.insert(item, at: 0)
        }
    }

    mutating func update(_ id: UUID, _ change: (inout ClipboardItem) -> Void) {
        if let index = pinned.firstIndex(where: { $0.id == id }) {
            change(&pinned[index])
        } else if let index = history.firstIndex(where: { $0.id == id }) {
            change(&history[index])
        }
    }

    /// Takes items out and says where each was, for `restore`.
    mutating func remove(_ ids: Set<UUID>) -> [Removal] {
        let fromPinned = pinned.enumerated().filter { ids.contains($0.element.id) }
            .map { Removal(item: $0.element, position: Position(section: .pinned, index: $0.offset)) }
        let fromHistory = history.enumerated().filter { ids.contains($0.element.id) }
            .map { Removal(item: $0.element, position: Position(section: .history, index: $0.offset)) }
        pinned.removeAll { ids.contains($0.id) }
        history.removeAll { ids.contains($0.id) }
        return fromPinned + fromHistory
    }

    /// Puts removed items back where they were. Inserting in the order of their old places rebuilds both lists exactly.
    mutating func restore(_ removals: [Removal]) {
        for removal in removals.sorted(by: { $0.position.index < $1.position.index }) where item(removal.item.id) == nil {
            switch removal.position.section {
            case .pinned: pinned.insert(removal.item, at: min(removal.position.index, pinned.count))
            case .history: history.insert(removal.item, at: min(removal.position.index, history.count))
            }
        }
    }

    /// Moves items, in their list order, into `section` before the item that is at `index` of that section now (its
    /// count for the end). Moving into Pinned pins an item; moving into History unpins it.
    mutating func move(_ ids: [UUID], to section: ClipboardSection, at index: Int) {
        let moving = Set(ids)
        let items = all.filter { moving.contains($0.id) }
        guard !items.isEmpty else { return }
        let destination = self.items(in: section)
        let clamped = max(0, min(index, destination.count))
        let movingAbove = destination[..<clamped].count { moving.contains($0.id) }
        pinned.removeAll { moving.contains($0.id) }
        history.removeAll { moving.contains($0.id) }
        switch section {
        case .pinned: pinned.insert(contentsOf: items, at: min(clamped - movingAbove, pinned.count))
        case .history: history.insert(contentsOf: items, at: min(clamped - movingAbove, history.count))
        }
    }

    /// Pins items at the end of Pinned, or unpins them to the top of the history. Items already there stay put.
    mutating func setPinned(_ ids: [UUID], _ isPinned: Bool) {
        let chosen = Set(ids)
        if isPinned {
            move(history.filter { chosen.contains($0.id) }.map(\.id), to: .pinned, at: pinned.count)
        } else {
            move(pinned.filter { chosen.contains($0.id) }.map(\.id), to: .history, at: 0)
        }
    }

    /// Drops the history items last copied more than `limits.days` ago, then those past `limits.items` from the
    /// bottom, then the oldest until everything takes at most `limits.bytes`. Pinned items always stay, and count
    /// toward the bytes. Returns what went.
    mutating func prune(_ limits: ClipboardLimits, now: Date) -> [ClipboardItem] {
        var removed: [ClipboardItem] = []
        if limits.days > 0 {
            let cutoff = now.addingTimeInterval(-Double(limits.days) * 86400)
            removed += history.filter { $0.lastCopied < cutoff }
            history.removeAll { $0.lastCopied < cutoff }
        }
        if limits.items > 0, history.count > limits.items {
            removed += history[limits.items...]
            history.removeSubrange(limits.items...)
        }
        if limits.bytes > 0 {
            var total = all.reduce(0) { $0 + $1.byteCount }
            while total > limits.bytes, let oldest = history.popLast() {
                removed.append(oldest)
                total -= oldest.byteCount
            }
        }
        return removed
    }
}
