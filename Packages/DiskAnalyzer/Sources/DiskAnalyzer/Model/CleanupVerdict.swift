/// How safe it is to clean a folder up, from what Oriel can check (PLAN §7.10 item 19), least cautious first, so the
/// most cautious of two is their `max`.
nonisolated enum CleanupVerdict: Int, Sendable, Comparable, CaseIterable {
    /// Rebuilt or downloaded again when needed, and nothing is using it: cleaning it up loses nothing.
    case safe
    /// It comes back by itself, but something needs doing first or instead: an app to quit, the tool's own command, a
    /// download that takes long.
    case careful
    /// Oriel cannot tell what it is: look inside first, and use the Trash.
    case review
    /// It holds what cannot be rebuilt (documents, settings, accounts, repositories), or macOS needs it.
    case keep

    static func < (lhs: CleanupVerdict, rhs: CleanupVerdict) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .safe: "Safe to clean up"
        case .careful: "Clean up with care"
        case .review: "Look before you remove it"
        case .keep: "Keep it"
        }
    }

    /// An SF Symbol.
    var symbol: String {
        switch self {
        case .safe: "checkmark.seal.fill"
        case .careful: "exclamationmark.triangle.fill"
        case .review: "questionmark.circle.fill"
        case .keep: "hand.raised.fill"
        }
    }
}
