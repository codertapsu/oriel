import OrielCore

public extension FeatureGuide {
    /// The window switcher's page in the feature tour (PLAN §19).
    nonisolated static let windowSwitcher = FeatureGuide(
        id: ModuleID.windowSwitcher.rawValue,
        title: "Window Switcher",
        symbol: "rectangle.stack",
        summary: "Switch between windows, not just apps: hold ⌥ and press ⇥, then let go on the window you want. "
            + "Settings → Window Switcher changes its keys.",
        highlights: [
            Highlight("Every window", "Thumbnails of your windows in every app and Space, most recent first."),
            Highlight("Search", "Type to find a window by its title or its app."),
            Highlight("Act on windows", "Close, minimize, make full screen or quit without leaving the switcher."),
            Highlight("In the Dock", "Rest the pointer on a Dock icon to see that app's windows."),
        ],
        permissions: [.accessibility, .screenRecording]
    )
}
