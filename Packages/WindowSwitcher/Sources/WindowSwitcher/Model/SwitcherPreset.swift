/// What a shortcut shows, in one choice (PLAN §7.1.11): every window, the active app's, every window grouped by app, or
/// the windows of the display the switcher opens on. A preset sets three of the shortcut's settings — the apps filter,
/// the screens filter and the grouping — and leaves the Spaces, minimized and hidden filters as they are, so a preset
/// and those refinements combine. A shortcut whose three settings match no preset (the active app on this display,
/// say) is a custom one, `nil` here.
///
/// It is derived from those settings rather than stored next to them, so the two can never disagree, and shortcuts
/// saved before presets existed show the preset they already amount to.
nonisolated enum SwitcherPreset: String, CaseIterable, Identifiable, Sendable {
    case allWindows
    case activeApp
    case groupedByApp
    case currentDisplay

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .allWindows: "All windows"
        case .activeApp: "Active app's windows"
        case .groupedByApp: "Windows grouped by app"
        case .currentDisplay: "This display's windows"
        }
    }

    /// The preset `spec` amounts to; nil for a custom mix.
    init?(_ spec: ShortcutSpec) {
        switch (spec.filter.apps, spec.filter.screens, spec.grouping) {
        case (.all, .all, .ungrouped): self = .allWindows
        case (.active, .all, .ungrouped): self = .activeApp
        case (.all, .all, .byApp): self = .groupedByApp
        case (.all, .current, .ungrouped): self = .currentDisplay
        default: return nil
        }
    }

    /// `spec` showing what this preset shows.
    func applied(to spec: ShortcutSpec) -> ShortcutSpec {
        var spec = spec
        spec.filter.apps = self == .activeApp ? .active : .all
        spec.filter.screens = self == .currentDisplay ? .current : .all
        spec.grouping = self == .groupedByApp ? .byApp : .ungrouped
        return spec
    }
}
