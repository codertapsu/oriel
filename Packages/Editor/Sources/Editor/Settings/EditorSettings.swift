import OrielCore

/// The editor's settings (Settings → Capture → Editor). They are the starting point of every new editor window;
/// changing the colour or width inside a window does not change them.
enum EditorSettings {
    /// Every key starts with this, for "reset this pane" (`SettingsStore.removeAll(withPrefix:)`).
    static let prefix = "editor."

    static let defaultColor = SettingKey("editor.defaultColor", default: RGBAColor.red)
    static let strokeWidth = SettingKey("editor.strokeWidth", default: Double(ToolStyle.defaultWidth))
    static let exportFormat = SettingKey("editor.exportFormat", default: EditorExportFormat.png)
    static let backgroundPreset = SettingKey("editor.backgroundPreset", default: BackgroundPreset.none)
}
