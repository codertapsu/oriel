import Foundation
import OrielCore

/// Disk Space Analyzer's settings, all named `disk.*` (Settings → Disk Space Analyzer).
nonisolated enum DiskSettings {
    static let prefix = "disk."

    /// Files below this many bytes are counted per folder rather than one by one.
    static let smallFileThreshold = SettingKey("disk.smallFileThreshold", default: 1_000_000)
    static let includesHiddenFiles = SettingKey("disk.includesHiddenFiles", default: true)
    static let crossesVolumes = SettingKey("disk.crossesVolumes", default: false)
    /// Paths (starting with `/` or `~`) and folder names a scan skips.
    static let exclusions = SettingKey("disk.exclusions", default: [String]())
    /// Ask Spotlight when the files Old Files lists were last opened.
    static let usesSpotlightDates = SettingKey("disk.usesSpotlightDates", default: true)
    /// Ask before moving items to the Trash. Deleting immediately always asks, twice.
    static let confirmsTrash = SettingKey("disk.confirmsTrash", default: true)
    /// Keep the open scan up to date as files change, while the window is open.
    static let watchesChanges = SettingKey("disk.watchesChanges", default: true)
    /// Remember a summary of each scan, to show what grew since.
    static let remembersScans = SettingKey("disk.remembersScans", default: true)
    /// Whether the note about macOS asking for folder access was shown before a first scan of the home folder.
    static let explainedFolderAccess = SettingKey("disk.explainedFolderAccess", default: false)
    /// The view the window opens on.
    static let view = SettingKey("disk.view", default: "sunburst")
    /// Old Files lists files not used for this many days.
    static let oldFileDays = SettingKey("disk.oldFileDays", default: 365)

    static let thresholdChoices = [100_000, 500_000, 1_000_000, 5_000_000, 10_000_000]
    static let oldFileChoices = [30, 90, 180, 365, 730, 1825]

    @MainActor
    static func scanOptions(in settings: SettingsStore, firmlinks: FirmlinkMap) -> ScanOptions {
        var options = ScanOptions()
        options.smallFileThreshold = Int64(max(1, settings[smallFileThreshold]))
        options.includesHiddenFiles = settings[includesHiddenFiles]
        options.crossesVolumes = settings[crossesVolumes]
        options.exclusions = ExclusionRules(settings[exclusions], home: NSHomeDirectory(), firmlinks: firmlinks)
        return options
    }
}
