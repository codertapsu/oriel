/// A row of the list: a process, or an app with its helpers below it. Flat views have no children.
nonisolated struct ListNode: Sendable, Equatable {
    /// What the row stands for. A group and its app's own process are separate rows, so they need separate keys.
    enum Key: Hashable, Sendable {
        case process(ProcessIdentity)
        case group(ProcessIdentity)

        var identity: ProcessIdentity {
            switch self {
            case let .process(identity), let .group(identity): identity
            }
        }
    }

    let key: Key
    /// The process, or for a group the totals of its members.
    var metrics: ProcessMetrics
    var children: [ListNode]

    init(key: Key, metrics: ProcessMetrics, children: [ListNode] = []) {
        self.key = key
        self.metrics = metrics
        self.children = children
    }

    init(_ process: ProcessMetrics) {
        self.init(key: .process(process.id), metrics: process)
    }

    var isGroup: Bool {
        if case .group = key {
            return true
        }
        return false
    }

    /// Every process row at or under this node.
    var allProcesses: [ProcessMetrics] {
        isGroup ? children.flatMap(\.allProcesses) : [metrics] + children.flatMap(\.allProcesses)
    }
}
