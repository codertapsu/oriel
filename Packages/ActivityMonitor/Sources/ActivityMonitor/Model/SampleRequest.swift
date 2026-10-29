/// What the next sample should read, from what the window shows: a tab without network columns does not start
/// nettop, and a list without other users' processes does not start `ps`.
nonisolated struct SampleRequest: Sendable, Equatable {
    var sources: SampleSources
    /// The running apps, read on the main thread: names, icons and grouping.
    var apps: [Int32: AppInfo]
    /// The process whose history the snapshot should carry.
    var selected: ProcessIdentity?
    var thresholds: HeavyThresholds
    /// Samples the graphs keep.
    var historyCapacity: Int

    init(
        sources: SampleSources,
        apps: [Int32: AppInfo] = [:],
        selected: ProcessIdentity? = nil,
        thresholds: HeavyThresholds = HeavyThresholds(),
        historyCapacity: Int = 150
    ) {
        self.sources = sources
        self.apps = apps
        self.selected = selected
        self.thresholds = thresholds
        self.historyCapacity = historyCapacity
    }
}
