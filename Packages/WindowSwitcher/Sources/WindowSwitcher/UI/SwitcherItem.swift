/// One tile or row of the switcher: a window, or in the app-icons style an app represented by its most
/// recently used window.
nonisolated struct SwitcherItem: Sendable, Equatable, Identifiable {
    /// What commit, hover actions and the preview act on.
    var entry: WindowEntry
    /// The app's windows in the list (app-icons style); 1 otherwise.
    var windowCount: Int
    /// `Character` offsets of search matches in the title and app name.
    var titleMatches: [Int]
    var appMatches: [Int]
    var badges: [WindowBadge]
    var accessibilityLabel: String

    var id: UInt32 {
        entry.id
    }

    /// "Title — App, minimized, Space 2" (PLAN §7.1.9); the app alone when the title is just its name.
    static func accessibilityLabel(title: String, appName: String, badges: [WindowBadge], windowCount: Int = 1) -> String {
        var label = title.isEmpty || title == appName ? appName : "\(title) — \(appName)"
        if windowCount > 1 {
            label += ", \(windowCount) windows"
        }
        for badge in badges {
            label += ", \(badge.spokenLabel)"
        }
        return label
    }
}
