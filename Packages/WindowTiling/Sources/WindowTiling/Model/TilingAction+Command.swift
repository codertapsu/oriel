import OrielCore

extension TilingAction {
    /// The action as the app's command: a shortcut (Settings → Shortcuts), in the Tools group, and left out of the
    /// status menu's list, because the Window Tiling submenu shows it.
    nonisolated func command(perform: @escaping @MainActor @Sendable () -> Void) -> ToolCommand {
        ToolCommand(
            id: commandID,
            title: title,
            symbol: symbol,
            group: .tools,
            defaultShortcut: defaultShortcut,
            showsInMenu: false,
            perform: perform
        )
    }

    /// Where the app keeps the user's shortcut for the action.
    nonisolated var shortcutKey: SettingKey<KeyCombo?> {
        command {}.shortcutKey
    }
}
