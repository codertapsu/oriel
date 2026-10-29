/// `oriel top --sort`: what the snapshot ranks processes by.
nonisolated enum TopSort: String, CaseIterable, Sendable, Codable {
    case cpu
    case memory
    case disk
    case network

    var processSort: ProcessSort {
        switch self {
        case .cpu: ProcessSort(column: .cpu, ascending: false)
        case .memory: ProcessSort(column: .memory, ascending: false)
        case .disk: ProcessSort(column: .diskWrittenRate, ascending: false)
        case .network: ProcessSort(column: .receivedRate, ascending: false)
        }
    }

    /// Ranks by reads and writes, or traffic in and out, together.
    func precedes(_ lhs: ProcessMetrics, _ rhs: ProcessMetrics) -> Bool {
        switch self {
        case .cpu, .memory:
            return processSort.precedes(lhs, rhs)
        case .disk, .network:
            let left = self == .disk ? lhs.diskPerSecond : lhs.network?.total
            let right = self == .disk ? rhs.diskPerSecond : rhs.network?.total
            switch (left, right) {
            case let (left?, right?) where left != right: return left > right
            case (.some, nil): return true
            case (nil, .some): return false
            default: return ProcessSort(column: .cpu, ascending: false).precedes(lhs, rhs)
            }
        }
    }
}
