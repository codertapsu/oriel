import Darwin

/// What the list shows for the latest snapshot, the view, the search and the order of each tab, and what the next sample
/// has to read for it. No AppKit, so it is tested directly.
final class ActivityListModel {
    let myUID: UInt32
    private(set) var snapshot: ActivitySnapshot?
    private(set) var roots: [ListNode] = []
    /// Folded search text by process, kept while the name stays the same.
    private var haystacks: [ProcessIdentity: (name: String, text: String)] = [:]

    var tab = ActivityTab.cpu {
        didSet {
            if tab != oldValue {
                rebuild()
            }
        }
    }

    var filter = ViewFilter.all {
        didSet {
            if filter != oldValue {
                rebuild()
            }
        }
    }

    var query = "" {
        didSet {
            if query != oldValue {
                rebuild()
            }
        }
    }

    /// Settings → Activity Monitor → Show only my processes.
    var onlyMine = false {
        didSet {
            if onlyMine != oldValue {
                rebuild()
            }
        }
    }

    var sorts: [ActivityTab: ProcessSort] = [:] {
        didSet {
            if sorts != oldValue {
                rebuild()
            }
        }
    }

    init(myUID: UInt32 = geteuid()) {
        self.myUID = myUID
    }

    var sort: ProcessSort {
        sorts[tab] ?? tab.defaultSort
    }

    /// The view actually in effect: a view about other users shows everything while only the user's own are listed.
    var effectiveFilter: ViewFilter {
        onlyMine && filter.isAboutOtherUsers ? .all : filter
    }

    func update(_ snapshot: ActivitySnapshot) {
        self.snapshot = snapshot
        let current = Set(snapshot.processes.map(\.id))
        haystacks = haystacks.filter { current.contains($0.key) }
        rebuild()
    }

    /// What the next sample must read for this tab and view. `ps` runs only when another user's CPU or memory is on
    /// screen, nettop only on the Network tab.
    var sources: SampleSources {
        var sources: SampleSources = .devices
        if !onlyMine, effectiveFilter.includesOtherUsers, [.cpu, .memory, .energy].contains(tab) {
            sources.insert(.otherUsers)
        }
        if tab == .network {
            sources.insert(.network)
        }
        if tab == .energy {
            sources.insert(.sleepAssertions)
        }
        return sources
    }

    /// The processes the user may see at all.
    var visibleProcesses: [ProcessMetrics] {
        let processes = snapshot?.processes ?? []
        return onlyMine ? processes.filter(\.isMine) : processes
    }

    func process(_ identity: ProcessIdentity) -> ProcessMetrics? {
        snapshot?.processes.first { $0.id == identity }
    }

    var isSearching: Bool {
        !ProcessSearch.terms(in: query).isEmpty
    }

    /// Process rows listed, counting a group's members rather than the group.
    var shownCount: Int {
        func count(_ node: ListNode) -> Int {
            node.children.reduce(node.isGroup ? 0 : 1) { $0 + count($1) }
        }
        return roots.reduce(0) { $0 + count($1) }
    }

    /// The three processes using the most of the tab's measure, whatever the view: what the strip above the list names.
    func topConsumers(limit: Int = 3) -> [ProcessMetrics] {
        let minimum = minimum
        var ranked: [(process: ProcessMetrics, value: Double)] = []
        for process in visibleProcesses {
            if let value = measure(of: process), value > minimum {
                ranked.append((process, value))
            }
        }
        ranked.sort { $0.value == $1.value ? $0.process.pid < $1.process.pid : $0.value > $1.value }
        return ranked.prefix(limit).map(\.process)
    }

    /// The tab's measure for `process`: CPU, memory, power, disk or network per second.
    func measure(of process: ProcessMetrics) -> Double? {
        switch tab {
        case .cpu: process.cpuPercent
        case .memory: process.memoryForRanking.map { Double($0) }
        case .energy: process.power
        case .disk: process.diskPerSecond
        case .network: process.network?.total
        }
    }

    /// Below this a process is not worth naming: 0.5 % CPU, 1 MB, 10 mW, or 1 KB/s.
    private var minimum: Double {
        switch tab {
        case .cpu: 0.5
        case .memory: 1_000_000
        case .energy: 0.01
        case .disk, .network: 1000
        }
    }

    func rebuild() {
        let terms = ProcessSearch.terms(in: query)
        let filter = effectiveFilter
        let myUID = myUID
        let processes = visibleProcesses
        let sort = sort
        let include: (ProcessMetrics) -> Bool = { process in
            filter.includes(process, myUID: myUID) && (terms.isEmpty || self.matches(process, terms))
        }
        switch filter {
        case .hierarchy:
            roots = ProcessTree.hierarchy(processes, sort: sort, include: include)
        case .appsWithHelpers:
            roots = ProcessGrouping.groups(processes, sort: sort, include: include)
        default:
            roots = sort.sorted(processes.filter(include)).map { ListNode($0) }
        }
    }

    private func matches(_ process: ProcessMetrics, _ terms: [String]) -> Bool {
        let text: String
        if let cached = haystacks[process.id], cached.name == process.name {
            text = cached.text
        } else {
            text = ProcessSearch.haystack(for: process)
            haystacks[process.id] = (process.name, text)
        }
        return ProcessSearch.matches(process, haystack: text, terms: terms)
    }
}
