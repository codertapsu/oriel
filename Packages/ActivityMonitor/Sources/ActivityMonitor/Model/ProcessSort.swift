import Foundation

/// The list's order: a column and a direction. Unknown values (a dash) always go last, whichever the direction. Rows
/// that tie are ordered by the column's companion (Read/s for Written/s, CPU time for % CPU), then by pid, so they do
/// not trade places at every update and a busy row is not lost among idle ones.
nonisolated struct ProcessSort: Sendable, Equatable, Codable {
    var column: ActivityColumn
    var ascending: Bool

    func sorted(_ processes: [ProcessMetrics]) -> [ProcessMetrics] {
        processes.sorted(by: precedes)
    }

    func precedes(_ lhs: ProcessMetrics, _ rhs: ProcessMetrics) -> Bool {
        if let decision = decide(column, lhs, rhs) {
            return decision
        }
        if let companion = Self.companion(of: column), let decision = decide(companion, lhs, rhs) {
            return decision
        }
        return lhs.pid < rhs.pid
    }

    /// The measure that orders rows tied on `column`.
    static func companion(of column: ActivityColumn) -> ActivityColumn? {
        switch column {
        case .cpu: .cpuTime
        case .power, .idleWakeups: .cpu
        case .memory: .realMemory
        case .diskWrittenRate: .diskReadRate
        case .diskReadRate: .diskWrittenRate
        case .diskWritten: .diskRead
        case .diskRead: .diskWritten
        case .sentRate: .receivedRate
        case .receivedRate: .sentRate
        case .sent: .received
        case .received: .sent
        default: nil
        }
    }

    private func decide(_ column: ActivityColumn, _ lhs: ProcessMetrics, _ rhs: ProcessMetrics) -> Bool? {
        switch column {
        case .name: names(lhs.name, rhs.name)
        case .cpu: order(lhs.cpuPercent, rhs.cpuPercent)
        case .cpuTime: order(lhs.cpuTime, rhs.cpuTime)
        case .threads: order(lhs.threads, rhs.threads)
        case .idleWakeups: order(lhs.idleWakeupsPerSecond, rhs.idleWakeupsPerSecond)
        case .kind: order(lhs.kind.title, rhs.kind.title)
        case .status: order(lhs.status?.title, rhs.status?.title)
        case .pid: order(lhs.pid, rhs.pid)
        case .user: names(lhs.user, rhs.user)
        case .memory: order(lhs.memoryForRanking, rhs.memoryForRanking)
        case .realMemory: order(lhs.realMemory, rhs.realMemory)
        case .power: order(lhs.power, rhs.power)
        case .preventingSleep: order(lhs.preventsSleep ? 1 : 0, rhs.preventsSleep ? 1 : 0)
        case .diskWritten: order(lhs.diskWritten, rhs.diskWritten)
        case .diskRead: order(lhs.diskRead, rhs.diskRead)
        case .diskWrittenRate: order(lhs.diskWrittenPerSecond, rhs.diskWrittenPerSecond)
        case .diskReadRate: order(lhs.diskReadPerSecond, rhs.diskReadPerSecond)
        case .sentRate: order(lhs.network?.sent, rhs.network?.sent)
        case .receivedRate: order(lhs.network?.received, rhs.network?.received)
        case .sent: order(lhs.networkTotal?.sent, rhs.networkTotal?.sent)
        case .received: order(lhs.networkTotal?.received, rhs.networkTotal?.received)
        }
    }

    /// True when `lhs` goes first, false when `rhs` does, nil when they tie.
    private func order<Value: Comparable>(_ lhs: Value?, _ rhs: Value?) -> Bool? {
        switch (lhs, rhs) {
        case let (left?, right?): left == right ? nil : (ascending ? left < right : left > right)
        case (.some, nil): true
        case (nil, .some): false
        case (nil, nil): nil
        }
    }

    /// Names as Finder orders them: ignoring case, with numbers by value.
    private func names(_ lhs: String, _ rhs: String) -> Bool? {
        switch lhs.localizedStandardCompare(rhs) {
        case .orderedSame: nil
        case .orderedAscending: ascending
        case .orderedDescending: !ascending
        }
    }
}
