/// A column of the process list. The raw value is the column's identifier, which AppKit uses to remember its width.
nonisolated enum ActivityColumn: String, CaseIterable, Sendable, Codable {
    case name
    case cpu
    case cpuTime
    case threads
    case idleWakeups
    case kind
    case status
    case pid
    case user
    case memory
    case realMemory
    case power
    case preventingSleep
    case diskWritten
    case diskRead
    case diskWrittenRate
    case diskReadRate
    case sentRate
    case receivedRate
    case sent
    case received

    var title: String {
        switch self {
        case .name: "Process Name"
        case .cpu: "% CPU"
        case .cpuTime: "CPU Time"
        case .threads: "Threads"
        case .idleWakeups: "Idle Wake-Ups"
        case .kind: "Kind"
        case .status: "Status"
        case .pid: "PID"
        case .user: "User"
        case .memory: "Memory"
        case .realMemory: "Real Memory"
        case .power: "Power"
        case .preventingSleep: "Preventing Sleep"
        case .diskWritten: "Bytes Written"
        case .diskRead: "Bytes Read"
        case .diskWrittenRate: "Written/s"
        case .diskReadRate: "Read/s"
        case .sentRate: "Sent/s"
        case .receivedRate: "Received/s"
        case .sent: "Sent"
        case .received: "Received"
        }
    }

    /// Explains the columns whose meaning is not obvious, or that macOS shares only for the user's own processes.
    var headerToolTip: String? {
        switch self {
        case .cpu: "Share of one core over the last interval; a process using several cores goes over 100 %."
        case .idleWakeups: "How often per second the process woke the processor up. Yours only."
        case .memory: "The memory the process takes, compressed memory included. For other users' processes, real memory."
        case .realMemory: "Memory the process has in RAM now, including memory shared with other processes."
        case .power: "Power the process drew over the last interval, as macOS measures it. Yours only."
        case .preventingSleep: "Keeps the Mac or its display from sleeping."
        case .diskWritten, .diskRead: "Since the process started. Yours only."
        case .diskWrittenRate, .diskReadRate: "Over the last interval. Yours only."
        case .sent, .received: "Counted while the Network tab shows."
        case .threads: "Yours only."
        case .kind: "Apple silicon, or Intel code running under Rosetta."
        default: nil
        }
    }

    /// Sized so every tab's columns fit beside the details pane in the default window; the name takes what is left.
    var width: Double {
        switch self {
        case .name: 220
        case .user: 92
        case .preventingSleep: 104
        case .status: 70
        case .kind, .pid, .threads: 56
        case .cpu: 64
        case .idleWakeups: 88
        case .power, .sent: 70
        case .cpuTime, .sentRate, .diskReadRate, .diskWrittenRate: 76
        case .received, .memory, .diskRead: 82
        case .receivedRate: 92
        case .realMemory, .diskWritten: 90
        }
    }

    /// Numbers align right, in monospaced digits.
    var isNumeric: Bool {
        switch self {
        case .name, .kind, .status, .user, .preventingSleep: false
        default: true
        }
    }

    /// The direction a click first sorts in: names and ids from A and 1, amounts largest first.
    var sortsAscendingFirst: Bool {
        switch self {
        case .name, .kind, .status, .pid, .user: true
        default: false
        }
    }
}
