import Foundation

/// One process as the list shows it: who it is and what it used over the last interval. A value macOS does not share
/// for this process, or one that needs a second sample, is nil and shows as a dash.
nonisolated struct ProcessMetrics: Sendable, Equatable, Identifiable {
    let id: ProcessIdentity
    var parentPID: Int32
    var uid: UInt32
    var user: String
    /// The app's name, else the executable's file name, else the kernel's short name.
    var name: String
    /// The kernel's short name.
    var command: String
    var path: String?
    var app: AppInfo?
    var kind: ProcessKind
    var status: ProcessStatus?
    /// Owned by the user running Oriel, so macOS shares all of its numbers.
    var isMine: Bool
    var cpuPercent: Double?
    /// Nanoseconds.
    var cpuTime: UInt64?
    var threads: Int?
    var idleWakeupsPerSecond: Double?
    /// The physical footprint ("Memory").
    var memory: UInt64?
    /// The resident set ("Real Memory").
    var realMemory: UInt64?
    /// Watts.
    var power: Double?
    var diskRead: UInt64?
    var diskWritten: UInt64?
    var diskReadPerSecond: Double?
    var diskWrittenPerSecond: Double?
    var network: TrafficRate?
    /// What it received and sent while Activity Monitor was open.
    var networkTotal: TrafficBytes?
    var sleepAssertions: [String] = []
    var heavy: HeavyFlags = []

    var pid: Int32 {
        id.pid
    }

    var startDate: Date {
        Date(timeIntervalSince1970: Double(id.startTime) / 1_000_000)
    }

    var isApp: Bool {
        app?.isRegular == true
    }

    /// Memory for sorting and thresholds: the footprint, else the resident set, which is all `ps` gives for other users.
    var memoryForRanking: UInt64? {
        memory ?? realMemory
    }

    var diskPerSecond: Double? {
        switch (diskReadPerSecond, diskWrittenPerSecond) {
        case let (read?, written?): read + written
        case let (read?, nil): read
        case let (nil, written?): written
        case (nil, nil): nil
        }
    }

    var preventsSleep: Bool {
        !sleepAssertions.isEmpty
    }
}
