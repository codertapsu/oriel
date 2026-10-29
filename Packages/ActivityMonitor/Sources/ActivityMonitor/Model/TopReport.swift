import Foundation

/// `oriel top`: the busiest processes from two samples about a second apart, as a table or as JSON.
nonisolated struct TopReport: Sendable {
    /// The JSON form. Values macOS does not share for a process are left out.
    struct Document: Codable, Sendable, Equatable {
        var sort: String
        var seconds: Double
        var system: System
        var processes: [Process]
    }

    struct System: Codable, Sendable, Equatable {
        var processes: Int
        var cpuUser: Double?
        var cpuSystem: Double?
        var memoryPhysical: UInt64?
        var memoryUsed: UInt64?
        var swapUsed: UInt64?
        var memoryPressure: String?
        var diskReadPerSecond: Double?
        var diskWrittenPerSecond: Double?
        var networkReceivedPerSecond: Double?
        var networkSentPerSecond: Double?
        var thermalState: String
    }

    struct Process: Codable, Sendable, Equatable {
        var pid: Int32
        var parentPID: Int32
        var name: String
        var user: String
        var cpu: Double?
        var cpuTime: Double?
        var memory: UInt64?
        var realMemory: UInt64?
        var threads: Int?
        var diskReadPerSecond: Double?
        var diskWrittenPerSecond: Double?
        var networkReceivedPerSecond: Double?
        var networkSentPerSecond: Double?
        var kind: String
        var status: String?
        var path: String?
        var bundleID: String?
    }

    static let defaultLimit = 20
    static let limits = 1 ... 1000

    let sort: TopSort
    let seconds: Double
    let processes: [ProcessMetrics]
    let system: SystemMetrics

    /// The `limit` processes that rank first by `sort`.
    init(processes: [ProcessMetrics], system: SystemMetrics, sort: TopSort, limit: Int, seconds: Double) {
        self.sort = sort
        self.seconds = seconds
        self.processes = Array(processes.sorted(by: sort.precedes).prefix(max(1, limit)))
        self.system = system
    }

    var document: Document {
        Document(
            sort: sort.rawValue,
            seconds: (seconds * 100).rounded() / 100,
            system: systemDocument,
            processes: processes.map(Self.process)
        )
    }

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try ByteText.string(encoder.encode(document))
    }

    /// A summary line, then a table like top(1)'s, the name last so a long one does not push the numbers apart.
    var text: String {
        let header = Self.row(["PID", "%CPU", "MEMORY", "DISK/s", "NET/s"], user: "USER", name: "NAME")
        let rows = processes.map { process in
            Self.row(
                [
                    String(process.pid),
                    ActivityFormat.percent(process.cpuPercent, locale: ActivityFormat.posix),
                    ActivityFormat.memory(process.memoryForRanking, locale: ActivityFormat.posix),
                    ActivityFormat.rate(process.diskPerSecond, locale: ActivityFormat.posix),
                    ActivityFormat.rate(process.network?.total, locale: ActivityFormat.posix),
                ],
                user: process.user,
                name: process.name
            )
        }
        var lines = [summary, ""]
        if sort == .disk {
            lines.insert("macOS shares disk use only for your own processes.", at: 1)
        }
        return (lines + [header] + rows).joined(separator: "\n")
    }

    private var summary: String {
        let posix = ActivityFormat.posix
        var parts = ["\(system.processCount) processes"]
        if let cpu = system.cpu {
            let user = ActivityFormat.percentWithSign(cpu.user * 100, locale: posix)
            parts.append("CPU \(user) user, \(ActivityFormat.percentWithSign(cpu.system * 100, locale: posix)) system")
        }
        if let memory = system.memory {
            let used = ActivityFormat.memory(memory.used, locale: posix)
            parts.append("memory \(used) of \(ActivityFormat.memory(memory.physical, locale: posix)) used")
        }
        if let pressure = system.pressure {
            parts.append("pressure \(pressure.level.title.lowercased())")
        }
        return parts.joined(separator: " · ")
    }

    private var systemDocument: System {
        System(
            processes: system.processCount,
            cpuUser: system.cpu.map { ($0.user * 1000).rounded() / 10 },
            cpuSystem: system.cpu.map { ($0.system * 1000).rounded() / 10 },
            memoryPhysical: system.memory?.physical,
            memoryUsed: system.memory?.used,
            swapUsed: system.memory?.swapUsed,
            memoryPressure: system.pressure?.level.rawValue,
            diskReadPerSecond: system.disk?.readBytesPerSecond.rounded(),
            diskWrittenPerSecond: system.disk?.writtenBytesPerSecond.rounded(),
            networkReceivedPerSecond: system.network?.bytesPerSecond.received.rounded(),
            networkSentPerSecond: system.network?.bytesPerSecond.sent.rounded(),
            thermalState: system.thermal.rawValue
        )
    }

    private static func process(_ process: ProcessMetrics) -> Process {
        Process(
            pid: process.pid,
            parentPID: process.parentPID,
            name: process.name,
            user: process.user,
            cpu: process.cpuPercent.map { ($0 * 10).rounded() / 10 },
            cpuTime: process.cpuTime.map { Double($0 / 10_000_000) / 100 },
            memory: process.memory,
            realMemory: process.realMemory,
            threads: process.threads,
            diskReadPerSecond: process.diskReadPerSecond?.rounded(),
            diskWrittenPerSecond: process.diskWrittenPerSecond?.rounded(),
            networkReceivedPerSecond: process.network?.received.rounded(),
            networkSentPerSecond: process.network?.sent.rounded(),
            kind: process.kind.rawValue,
            status: process.status?.rawValue,
            path: process.path,
            bundleID: process.app?.bundleID
        )
    }

    /// The numbers right-aligned in their widths, then the user cut to 15 characters, then the name.
    private static func row(_ numbers: [String], user: String, name: String) -> String {
        let widths = [6, 7, 11, 11, 11]
        let cells = zip(numbers, widths).map { pad($0, $1) }.joined()
        return cells + "  " + String(user.prefix(15)).padding(toLength: 15, withPad: " ", startingAt: 0) + "  " + name
    }

    /// Right-aligned in `width` characters.
    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? " " + text : String(repeating: " ", count: width - text.count) + text
    }
}
