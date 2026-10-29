/// Items deleted from the panel, kept until it closes so Undo can put them back where they were.
nonisolated struct ClipboardDeletion: Sendable, Equatable {
    let removals: [ClipboardIndex.Removal]

    var count: Int {
        removals.count
    }

    var isEmpty: Bool {
        removals.isEmpty
    }
}
