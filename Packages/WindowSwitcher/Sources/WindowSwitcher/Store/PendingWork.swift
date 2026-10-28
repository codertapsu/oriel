/// What the store still has to re-read, accumulated from events while a refresh is in flight. Bursts (a
/// resize sends dozens of notifications) collapse into one re-read per app, without timers.
nonisolated struct PendingWork: Sendable, Equatable {
    var applications = false
    var server = false
    /// Re-read every app's AX windows: after a Space change AX lists different windows.
    var allApps = false
    var pids: Set<Int32> = []
    /// Apps whose focused window to read for the MRU order, oldest first.
    var focusPIDs: [Int32] = []
    var terminated: Set<Int32> = []

    var isEmpty: Bool {
        self == PendingWork()
    }

    /// Records `event`. Apps in `refused` are retried when they are activated (PLAN §7.1.1).
    mutating func add(_ event: WindowSourceEvent, refused: Set<Int32>) {
        switch event {
        case let .appLaunched(pid):
            applications = true
            server = true
            pids.insert(pid)
        case let .appTerminated(pid):
            applications = true
            server = true
            pids.remove(pid)
            focusPIDs.removeAll { $0 == pid }
            terminated.insert(pid)
        case let .appActivated(pid):
            applications = true
            noteFocus(pid)
            if refused.contains(pid) {
                pids.insert(pid)
            }
        case let .appHidden(pid), let .appUnhidden(pid):
            applications = true
            server = true
            pids.insert(pid)
        case let .windowsChanged(pid):
            server = true
            pids.insert(pid)
        case let .focusedWindowChanged(pid):
            noteFocus(pid)
        case .activeSpaceChanged:
            allApps = true
            server = true
        case .screensChanged:
            server = true
        case .sessionResumed:
            applications = true
            allApps = true
            server = true
        }
    }

    private mutating func noteFocus(_ pid: Int32) {
        focusPIDs.removeAll { $0 == pid }
        focusPIDs.append(pid)
    }
}
