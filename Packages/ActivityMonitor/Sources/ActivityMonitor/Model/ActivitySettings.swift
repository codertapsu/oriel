import OrielCore

/// Activity Monitor's settings, all named `activity.*` (Settings → Activity Monitor).
nonisolated enum ActivitySettings {
    static let prefix = "activity."

    /// Seconds between samples while the window is open.
    static let interval = SettingKey("activity.interval", default: 2)
    /// The tab the window opens on, an `ActivityTab` raw value.
    static let defaultTab = SettingKey("activity.defaultTab", default: ActivityTab.cpu.rawValue)
    /// Lists only the user's own processes, and never starts `ps`.
    static let onlyMyProcesses = SettingKey("activity.onlyMyProcesses", default: false)
    /// The view the window last showed, a `ViewFilter` raw value.
    static let viewFilter = SettingKey("activity.viewFilter", default: ViewFilter.all.rawValue)
    /// Minutes of history the graphs keep.
    static let historyMinutes = SettingKey("activity.historyMinutes", default: 5)
    static let cpuThreshold = SettingKey("activity.cpuThreshold", default: 80)
    static let thresholdSeconds = SettingKey("activity.thresholdSeconds", default: 10)
    /// In tenths of a gigabyte (1,000,000,000 bytes), so the picker's choices stay exact.
    static let memoryThresholdTenths = SettingKey("activity.memoryThresholdTenths", default: 20)
    static let diskThresholdMB = SettingKey("activity.diskThresholdMB", default: 50)
    static let networkThresholdMB = SettingKey("activity.networkThresholdMB", default: 5)
    /// Whether the details pane is open.
    static let showsInspector = SettingKey("activity.showsInspector", default: true)

    static let intervalChoices = [1, 2, 5]
    static let historyChoices = [1, 5, 15, 30]
    static let cpuThresholdChoices = [50, 80, 100, 150, 200, 400]
    static let thresholdSecondsChoices = [5, 10, 30, 60]
    static let memoryThresholdChoices = [5, 10, 20, 40, 80, 160]
    static let diskThresholdChoices = [10, 50, 100, 500]
    static let networkThresholdChoices = [1, 5, 10, 50]

    /// A sort per tab, `activity.sort.<tab>`.
    static func sort(for tab: ActivityTab) -> SettingKey<ProcessSort> {
        SettingKey("activity.sort.\(tab.rawValue)", default: tab.defaultSort)
    }

    @MainActor
    static func thresholds(in settings: SettingsStore) -> HeavyThresholds {
        HeavyThresholds(
            cpuPercent: Double(settings[cpuThreshold]),
            seconds: Double(settings[thresholdSeconds]),
            memoryBytes: UInt64(max(1, settings[memoryThresholdTenths])) * 100_000_000,
            diskBytesPerSecond: Double(settings[diskThresholdMB]) * 1_000_000,
            networkBytesPerSecond: Double(settings[networkThresholdMB]) * 1_000_000
        )
    }

    /// The interval, held to the offered choices.
    @MainActor
    static func intervalSeconds(in settings: SettingsStore) -> Int {
        let value = settings[interval]
        return intervalChoices.contains(value) ? value : 2
    }

    /// How many samples the graphs keep.
    @MainActor
    static func historyCapacity(in settings: SettingsStore) -> Int {
        max(10, settings[historyMinutes] * 60 / intervalSeconds(in: settings))
    }
}
