import OrielCore

/// The Color Picker's settings, all named `colorPicker.*` (Settings → Color Picker).
nonisolated enum ColorPickerSettings {
    static let prefix = "colorPicker."

    /// What ⌘C in the panel, and copying on a pick, write.
    static let defaultFormat = SettingKey("colorPicker.defaultFormat", default: ColorFormat.hex)
    /// `#FF8800` rather than `#ff8800`.
    static let uppercaseHex = SettingKey("colorPicker.uppercaseHex", default: true)
    /// How many picks the history keeps.
    static let historySize = SettingKey("colorPicker.historySize", default: ColorLibrary.defaultHistoryLimit)
    /// Copy the picked color in the default format as soon as it is picked, as well as showing it in the panel.
    static let copiesOnPick = SettingKey("colorPicker.copiesOnPick", default: true)

    static let historySizeChoices = [10, 20, 50, 100]
}
