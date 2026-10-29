import OrielCore

/// Window Tiling's settings, all named `tiling.*` (Settings → Window Tiling). The shortcuts are the app's
/// (`shortcuts.tile…`, Settings → Shortcuts).
nonisolated enum TilingSettings {
    static let prefix = "tiling."

    /// Points between tiled windows and the screen's edges; 0 for none.
    static let gap = SettingKey("tiling.gap", default: 0.0)
    /// Pressing a half again steps through ½, ⅔ and ⅓ of the screen.
    static let cyclesSizes = SettingKey("tiling.cyclesSizes", default: true)
    /// Almost Maximize's share of the screen, from 0.6 to 0.95.
    static let almostMaximizeFraction = SettingKey("tiling.almostMaximizeFraction", default: 0.9)

    @MainActor
    static func options(in settings: SettingsStore) -> TilingOptions {
        TilingOptions(
            gap: settings[gap],
            cyclesSizes: settings[cyclesSizes],
            almostMaximizeFraction: settings[almostMaximizeFraction]
        )
    }
}
