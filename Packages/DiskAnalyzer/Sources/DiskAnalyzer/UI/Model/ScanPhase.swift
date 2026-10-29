/// Where the window's scan is.
nonisolated enum ScanPhase: Sendable, Equatable {
    case idle
    case scanning(ScanProgress)
    /// The tree is there; `stopped` when the user stopped the scan before the end, so it is partial.
    case ready(stopped: Bool)

    var isScanning: Bool {
        if case .scanning = self {
            return true
        }
        return false
    }
}
