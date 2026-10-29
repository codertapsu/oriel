/// How much history to keep: items, days and bytes, each 0 for no limit. Pinned items are outside all three.
nonisolated struct ClipboardLimits: Sendable, Equatable {
    var items: Int
    var days: Int
    var bytes: Int
}
