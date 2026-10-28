import Observation

/// Which Settings tab is showing, so "Settings…" from anywhere can open a given pane.
@MainActor
@Observable
final class SettingsNavigation {
    var tab = "general"
}
