/// The two groups of the list: pinned items, kept until unpinned, and the history, newest first.
nonisolated enum ClipboardSection: String, Codable, Sendable {
    case pinned
    case history

    var title: String {
        switch self {
        case .pinned: "Pinned"
        case .history: "History"
        }
    }
}
