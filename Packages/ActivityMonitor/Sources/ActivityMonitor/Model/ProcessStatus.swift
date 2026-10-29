/// What a process is doing, in the words `ps` and `top` use.
nonisolated enum ProcessStatus: String, Sendable, Codable, CaseIterable {
    case running
    case sleeping
    /// In an uninterruptible wait, usually for the disk (`ps` state U).
    case waiting
    case stopped
    /// Ended, but its parent has not collected its exit status yet.
    case zombie

    /// From the first letter of `ps`'s `state` column: R, S or I, U, T, Z.
    init?(psState: Substring) {
        switch psState.first {
        case "R": self = .running
        case "S", "I": self = .sleeping
        case "U", "D": self = .waiting
        case "T": self = .stopped
        case "Z": self = .zombie
        default: return nil
        }
    }

    /// From the kernel's process state (`p_stat`) and, for the user's own processes, how many threads are running.
    /// The kernel keeps every live process in SRUN, so the threads decide between running and sleeping.
    init(kernelState: Int8, runningThreads: Int?) {
        switch kernelState {
        case 4: self = .stopped // SSTOP
        case 5: self = .zombie // SZOMB
        default: self = (runningThreads ?? 0) > 0 ? .running : .sleeping
        }
    }

    var title: String {
        switch self {
        case .running: "Running"
        case .sleeping: "Sleeping"
        case .waiting: "Waiting"
        case .stopped: "Stopped"
        case .zombie: "Zombie"
        }
    }
}
