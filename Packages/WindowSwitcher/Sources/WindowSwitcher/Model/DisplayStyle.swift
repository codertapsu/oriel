/// How the switcher draws its items (PLAN §7.1.10).
nonisolated enum DisplayStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    /// A grid of live window thumbnails (needs Screen Recording; falls back to app icons in each tile).
    case thumbnails
    /// One tile per app with a window-count badge, like the system's Cmd-Tab.
    case appIcons
    /// A compact list of window titles.
    case titles

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .thumbnails: "Thumbnails"
        case .appIcons: "App icons"
        case .titles: "Titles"
        }
    }
}
