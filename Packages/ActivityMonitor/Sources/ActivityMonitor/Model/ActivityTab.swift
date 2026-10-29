/// The window's tabs, as in macOS's Activity Monitor: each has its columns, its summary and its default order.
nonisolated enum ActivityTab: String, CaseIterable, Sendable, Codable {
    case cpu
    case memory
    case energy
    case disk
    case network

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .energy: "Energy"
        case .disk: "Disk"
        case .network: "Network"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .energy: "bolt"
        case .disk: "internaldrive"
        case .network: "network"
        }
    }

    var columns: [ActivityColumn] {
        switch self {
        case .cpu: [.name, .cpu, .cpuTime, .threads, .idleWakeups, .kind, .status, .pid, .user]
        case .memory: [.name, .memory, .realMemory, .threads, .kind, .pid, .user]
        case .energy: [.name, .power, .cpu, .idleWakeups, .preventingSleep, .kind, .pid, .user]
        case .disk: [.name, .diskWrittenRate, .diskReadRate, .diskWritten, .diskRead, .kind, .pid, .user]
        case .network: [.name, .sentRate, .receivedRate, .sent, .received, .pid, .user]
        }
    }

    /// The busiest first.
    var defaultSort: ProcessSort {
        switch self {
        case .cpu: ProcessSort(column: .cpu, ascending: false)
        case .memory: ProcessSort(column: .memory, ascending: false)
        case .energy: ProcessSort(column: .power, ascending: false)
        case .disk: ProcessSort(column: .diskWrittenRate, ascending: false)
        case .network: ProcessSort(column: .receivedRate, ascending: false)
        }
    }

    /// The metric of the "Top" strip above the list and of heavy-use highlighting.
    var heavyFlag: HeavyFlags {
        switch self {
        case .cpu, .energy: .cpu
        case .memory: .memory
        case .disk: .disk
        case .network: .network
        }
    }

    /// ⌘1 to ⌘5.
    var keyEquivalent: String {
        String((Self.allCases.firstIndex(of: self) ?? 0) + 1)
    }
}
