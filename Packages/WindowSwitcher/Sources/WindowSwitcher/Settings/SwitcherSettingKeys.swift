import OrielCore

/// The switcher's settings (PLAN §7.1.4, §7.1.7, §7.1.10). Every name starts with `switcher.`.
nonisolated enum SwitcherSettingKeys {
    static let prefix = "switcher."

    static let enabled = SettingKey("switcher.enabled", default: true)
    static let shortcuts = SettingKey("switcher.shortcuts", default: [ShortcutSpec.optionTab])
    static let style = SettingKey("switcher.style", default: DisplayStyle.thumbnails)
    /// The largest thumbnail tile, in points.
    static let thumbnailWidth = SettingKey("switcher.thumbnailWidth", default: 220.0)
    static let showsPreview = SettingKey("switcher.showsPreview", default: true)
    /// The line under the tiles naming the keys that close, minimize, full-screen or quit (PLAN §7.1.4).
    static let showsKeyHints = SettingKey("switcher.showsKeyHints", default: true)
    /// Which display the panel opens on (PLAN §7.1.3).
    static let placement = SettingKey("switcher.placement", default: PanelPlacement.pointer)
    static let gesturesEnabled = SettingKey("switcher.gesturesEnabled", default: false)
    static let exceptions = SettingKey("switcher.exceptions", default: AppException.defaults)
    static let takesOverCommandTab = SettingKey("switcher.takesOverCommandTab", default: true)
    /// The symbolic hot keys the switcher turned off, written before turning them off, so they are turned
    /// back on at the next activation after a crash or `kill -9` (PLAN §7.1.4).
    static let disabledSymbolicHotKeys = SettingKey("switcher.disabledSymbolicHotKeys", default: [Int32]())
}
