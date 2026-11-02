import Observation
import OrielCore

/// Which Settings tab is showing, so "Settings…" from anywhere can open a given pane.
@MainActor
@Observable
final class SettingsNavigation {
    var tab = "general"
    /// The Pro feature the user just tried, for Settings → Oriel Pro to name (PLAN §19).
    var proFeature: ProFeature?
}
