import CoreGraphics
import OrielCore

/// One consistent reading of the switcher's settings.
nonisolated struct SwitcherConfiguration: Sendable, Equatable {
    var isEnabled = true
    var shortcuts: [ShortcutSpec] = [.optionTab]
    var style: DisplayStyle = .thumbnails
    var thumbnailWidth: CGFloat = 220
    var showsPreview = true
    var showsKeyHints = true
    var placement: PanelPlacement = .pointer
    var gesturesEnabled = false
    var exceptions = AppException.defaults
    var takesOverCommandTab = true

    /// Key codes that can open a shortcut, so the tap callback can skip everything else cheaply.
    var triggerKeys: Set<UInt16> {
        Set(shortcuts.filter(\.isEnabled).map(\.nextKey))
    }

    @MainActor
    static func load(from settings: SettingsStore) -> SwitcherConfiguration {
        SwitcherConfiguration(
            isEnabled: settings[SwitcherSettingKeys.enabled],
            shortcuts: sanitized(settings[SwitcherSettingKeys.shortcuts]),
            style: settings[SwitcherSettingKeys.style],
            thumbnailWidth: CGFloat(settings[SwitcherSettingKeys.thumbnailWidth]),
            showsPreview: settings[SwitcherSettingKeys.showsPreview],
            showsKeyHints: settings[SwitcherSettingKeys.showsKeyHints],
            placement: settings[SwitcherSettingKeys.placement],
            gesturesEnabled: settings[SwitcherSettingKeys.gesturesEnabled],
            exceptions: settings[SwitcherSettingKeys.exceptions],
            takesOverCommandTab: settings[SwitcherSettingKeys.takesOverCommandTab]
        )
    }

    /// At most nine shortcuts, each with a reverse modifier that does not overlap its hold modifiers.
    static func sanitized(_ shortcuts: [ShortcutSpec]) -> [ShortcutSpec] {
        shortcuts.prefix(ShortcutSpec.maximumCount).map { $0.normalized() }
    }
}
