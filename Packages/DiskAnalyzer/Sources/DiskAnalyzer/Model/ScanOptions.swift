import Foundation

/// How a scan counts and what it skips, from Settings → Disk Space Analyzer.
nonisolated struct ScanOptions: Sendable, Equatable {
    /// Files smaller than this are counted per folder ("1,204 smaller files, 312 MB") instead of one by one, which
    /// keeps a scan of millions of files to a few tens of megabytes.
    var smallFileThreshold: Int64 = 1_000_000
    var includesHiddenFiles = true
    /// Whether to go into other volumes mounted inside the scanned folder. Only local, browsable volumes are entered,
    /// never network shares, disk images macOS mounts for itself, or automounts.
    var crossesVolumes = false
    var exclusions = ExclusionRules()
    /// Directories read at once. Reading is mostly waiting for the disk, so a few more threads than cores help on
    /// SSDs without swamping a spinning disk.
    var workerCount = ScanOptions.defaultWorkerCount
    /// How often progress is reported, at most.
    var progressInterval: Duration = .milliseconds(120)

    static var defaultWorkerCount: Int {
        max(2, min(8, ProcessInfo.processInfo.activeProcessorCount))
    }
}
