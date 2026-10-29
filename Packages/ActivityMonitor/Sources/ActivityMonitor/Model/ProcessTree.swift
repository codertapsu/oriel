/// "All Processes, Hierarchically": each process under the one that started it. A process whose parent is not listed,
/// or whose "parent" started after it (the pid was reused), is a root. Siblings follow the list's order.
nonisolated enum ProcessTree {
    /// `include` picks the processes shown; their ancestors are kept too, so a match deep in the tree stays in place.
    static func hierarchy(_ processes: [ProcessMetrics], sort: ProcessSort, include: (ProcessMetrics) -> Bool) -> [ListNode] {
        let byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        func parent(of process: ProcessMetrics) -> ProcessMetrics? {
            guard process.parentPID != process.pid, let parent = byPID[process.parentPID], parent.id.startTime <= process.id.startTime
            else { return nil }
            return parent
        }
        var kept: Set<Int32> = []
        for process in processes where include(process) {
            var current: ProcessMetrics? = process
            // The walk stops at a root, at a process already kept, or after a cycle-proof number of steps.
            var steps = 0
            while let node = current, kept.insert(node.pid).inserted, steps < 512 {
                current = parent(of: node)
                steps += 1
            }
        }
        var children: [Int32: [ProcessMetrics]] = [:]
        var roots: [ProcessMetrics] = []
        for process in processes where kept.contains(process.pid) {
            if let parent = parent(of: process) {
                children[parent.pid, default: []].append(process)
            } else {
                roots.append(process)
            }
        }
        var visited: Set<Int32> = []
        func node(_ process: ProcessMetrics) -> ListNode {
            visited.insert(process.pid)
            let below = sort.sorted(children[process.pid] ?? []).filter { !visited.contains($0.pid) }
            return ListNode(key: .process(process.id), metrics: process, children: below.map(node))
        }
        return sort.sorted(roots).map(node)
    }
}
