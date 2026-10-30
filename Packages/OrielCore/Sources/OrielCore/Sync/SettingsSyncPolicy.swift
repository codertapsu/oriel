/// Which settings follow the user to their other Macs (PLAN §7.16). Preferences, tools and shortcuts do. Anything
/// tied to this Mac does not: folders and bookmarks, upload destinations (their credentials stay in this Mac's
/// keychain), one-time notices and the sync bookkeeping itself. Secrets never reach `SettingsStore` (rule 7).
public nonisolated enum SettingsSyncPolicy {
    /// Prefixes of the settings that sync.
    public static let syncedPrefixes = [
        "shortcuts.", "capture.", "recording.", "editor.", "translation.", "clipboard.", "switcher.", "disk.", "activity.",
        "colorPicker.", "screenRuler.", "tiling.",
    ]

    /// Settings outside those prefixes that sync too.
    public static let syncedNames: Set<String> = ["app.enabledModules"]

    /// Parts of a name, compared without case, that mark a setting as this Mac's own even under a synced prefix.
    public static let localMarkers = ["folder", "directory", "path", "bookmark", "location", "lastused", "lastopened", "lastscan"]

    /// Settings under a synced prefix that are this Mac's own although their names do not say so.
    public static let localNames: Set<String> = [
        "clipboard.openedPasteboardSettings", "disk.explainedFolderAccess", "disk.helperBuild",
    ]

    public static func syncs(_ name: String) -> Bool {
        if syncedNames.contains(name) {
            return true
        }
        guard syncedPrefixes.contains(where: name.hasPrefix), !localNames.contains(name) else { return false }
        let lowered = name.lowercased()
        return !localMarkers.contains(where: lowered.contains)
    }
}
