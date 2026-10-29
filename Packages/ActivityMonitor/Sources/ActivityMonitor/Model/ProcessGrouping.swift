/// "Apps with Their Helpers": each app in the Dock with the processes that work for it, and their totals on the app's
/// row. A process belongs to the app whose bundle holds its executable (helpers, XPC services, the innermost bundle if
/// apps nest), or else to the app that started it or one of its ancestors (a shell in Terminal, a server started by an
/// editor). macOS's own idea of a responsible process is private API, so this is the public approximation.
nonisolated enum ProcessGrouping {
    /// The app's row is the group; its members, the app's own process first, are below it. An app with no helpers is a
    /// plain row. Only apps whose group has a process `include` accepts are listed.
    static func groups(_ processes: [ProcessMetrics], sort: ProcessSort, include: (ProcessMetrics) -> Bool) -> [ListNode] {
        let owners = owners(of: processes)
        var members: [Int32: [ProcessMetrics]] = [:]
        for process in processes {
            if let owner = owners[process.pid] {
                members[owner, default: []].append(process)
            }
        }
        let apps = processes.filter { $0.isApp && members[$0.pid] != nil }
        let nodes: [ListNode] = apps.compactMap { app in
            let group = members[app.pid] ?? [app]
            let shown = include(app) ? group : group.filter(include)
            guard !shown.isEmpty else { return nil }
            guard group.count > 1 else { return ListNode(app) }
            let ordered = [app] + sort.sorted(shown.filter { $0.id != app.id })
            return ListNode(key: .group(app.id), metrics: totals(of: group, app: app), children: ordered.map { ListNode($0) })
        }
        return nodes.sorted { sort.precedes($0.metrics, $1.metrics) }
    }

    /// Each process's app, by pid.
    static func owners(of processes: [ProcessMetrics]) -> [Int32: Int32] {
        let byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        // Longest first, so a nested bundle wins over the one around it.
        let bundles = processes.compactMap { process -> (path: String, pid: Int32)? in
            guard process.isApp, let path = process.app?.bundlePath else { return nil }
            return (path.hasSuffix("/") ? path : path + "/", process.pid)
        }.sorted { $0.path.count > $1.path.count }
        var owners: [Int32: Int32] = [:]
        for process in processes {
            if process.isApp {
                owners[process.pid] = process.pid
            } else if let path = process.path, let bundle = bundles.first(where: { path.hasPrefix($0.path) }) {
                owners[process.pid] = bundle.pid
            }
        }
        for process in processes where owners[process.pid] == nil {
            var current = byPID[process.parentPID]
            var steps = 0
            while let ancestor = current, ancestor.pid > 1, steps < 64 {
                if let owner = owners[ancestor.pid] {
                    owners[process.pid] = owner
                    break
                }
                current = ancestor.parentPID == ancestor.pid ? nil : byPID[ancestor.parentPID]
                steps += 1
            }
        }
        return owners
    }

    /// The app's row: its identity and name, with what all its processes use added up.
    static func totals(of group: [ProcessMetrics], app: ProcessMetrics) -> ProcessMetrics {
        var total = app
        total.cpuPercent = sum(group.map(\.cpuPercent))
        total.cpuTime = sum(group.map(\.cpuTime))
        total.threads = sum(group.map(\.threads))
        total.idleWakeupsPerSecond = sum(group.map(\.idleWakeupsPerSecond))
        total.memory = sum(group.map(\.memoryForRanking))
        total.realMemory = sum(group.map(\.realMemory))
        total.power = sum(group.map(\.power))
        total.diskRead = sum(group.map(\.diskRead))
        total.diskWritten = sum(group.map(\.diskWritten))
        total.diskReadPerSecond = sum(group.map(\.diskReadPerSecond))
        total.diskWrittenPerSecond = sum(group.map(\.diskWrittenPerSecond))
        let rates = group.compactMap(\.network)
        total.network = rates.isEmpty ? nil : TrafficRate(
            received: rates.map(\.received).reduce(0, +),
            sent: rates.map(\.sent).reduce(0, +)
        )
        let bytes = group.compactMap(\.networkTotal)
        total.networkTotal = bytes.isEmpty ? nil : bytes.reduce(.zero, +)
        total.sleepAssertions = Array(Set(group.flatMap(\.sleepAssertions))).sorted()
        total.heavy = group.reduce(HeavyFlags()) { $0.union($1.heavy) }
        return total
    }

    /// The sum of the known values; nil when none is known.
    private static func sum<Value: AdditiveArithmetic>(_ values: [Value?]) -> Value? {
        let known = values.compactMap(\.self)
        return known.isEmpty ? nil : known.reduce(.zero, +)
    }
}
