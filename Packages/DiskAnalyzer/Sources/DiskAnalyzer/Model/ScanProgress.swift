/// How far a running scan has got, reported a few times a second.
nonisolated struct ScanProgress: Sendable, Equatable {
    var files = 0
    var folders = 0
    var bytes: Int64 = 0
    var unreadableFolders = 0
    /// The folder read last, as the user knows its path.
    var currentPath = ""
    var elapsed: Duration = .zero
}
