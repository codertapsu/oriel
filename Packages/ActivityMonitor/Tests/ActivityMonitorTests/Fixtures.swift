@testable import ActivityMonitor
import Foundation

/// Builders for the model's values, with defaults that keep each test to what it is about.
enum Fixtures {
    static let me: UInt32 = 501

    static func process(
        _ pid: Int32,
        name: String? = nil,
        parent: Int32 = 1,
        uid: UInt32 = me,
        start: UInt64? = nil,
        path: String? = nil,
        app: AppInfo? = nil,
        cpu: Double? = nil,
        memory: UInt64? = nil,
        realMemory: UInt64? = nil
    ) -> ProcessMetrics {
        ProcessMetrics(
            id: ProcessIdentity(pid: pid, startTime: start ?? UInt64(pid) * 1000),
            parentPID: parent,
            uid: uid,
            user: uid == 0 ? "root" : uid == me ? "me" : "_service",
            name: name ?? "process\(pid)",
            command: String((name ?? "process\(pid)").prefix(16)),
            path: path,
            app: app,
            kind: .apple,
            status: .sleeping,
            isMine: uid == me,
            cpuPercent: cpu,
            memory: memory,
            realMemory: realMemory
        )
    }

    static func app(_ name: String, bundle: String, regular: Bool = true) -> AppInfo {
        AppInfo(name: name, bundleID: "com.example.\(name.lowercased())", bundlePath: bundle, isRegular: regular)
    }

    static func basics(_ pid: Int32, uid: UInt32 = me, start: UInt64? = nil, command: String = "proc", state: Int8 = 2) -> ProcessBasics {
        ProcessBasics(
            pid: pid,
            parentPID: 1,
            uid: uid,
            startTime: start ?? UInt64(pid) * 1000,
            command: command,
            kernelState: state,
            isTranslated: false
        )
    }

    static func reading(
        _ pid: Int32,
        uid: UInt32 = me,
        start: UInt64? = nil,
        source: ProcessCounters.Source = .usage,
        cpuTime: UInt64? = nil,
        energy: UInt64? = nil,
        diskRead: UInt64? = nil,
        network: ProcessNetwork? = nil
    ) -> ProcessReading {
        ProcessReading(
            basics: basics(pid, uid: uid, start: start),
            path: "/usr/bin/proc\(pid)",
            counters: ProcessCounters(source: source, cpuTime: cpuTime, footprint: 1_000_000, diskRead: diskRead, energy: energy),
            network: network
        )
    }

    /// `seconds` after boot, in the sampler's nanoseconds.
    static func time(_ seconds: Double) -> UInt64 {
        UInt64(seconds * 1_000_000_000)
    }
}
