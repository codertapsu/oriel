import AppIntents

/// The shortcuts Oriel offers without setup, in Spotlight and the Shortcuts app (PLAN §7.17).
nonisolated struct OrielShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureIntent(),
            phrases: ["Take a screenshot with \(.applicationName)", "Capture with \(.applicationName)"],
            shortTitle: "Take a Screenshot",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: TranslateAreaIntent(),
            phrases: ["Translate the screen with \(.applicationName)"],
            shortTitle: "Translate Area",
            systemImageName: "character.bubble"
        )
        #if !APP_STORE
            AppShortcut(
                intent: FocusWindowIntent(),
                phrases: ["Focus a window with \(.applicationName)"],
                shortTitle: "Focus Window",
                systemImageName: "macwindow"
            )
        #endif
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: ["Run an \(.applicationName) command"],
            shortTitle: "Run Oriel Command",
            systemImageName: "command"
        )
    }
}
