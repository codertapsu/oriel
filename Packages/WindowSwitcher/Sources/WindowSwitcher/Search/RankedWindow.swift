/// A window that matched the search, with the matched characters of its title and app name.
nonisolated struct RankedWindow: Sendable, Equatable {
    var entry: WindowEntry
    var score: Int
    /// `Character` offsets into `entry.info.title`.
    var titleMatches: [Int]
    /// `Character` offsets into `entry.info.appName`.
    var appMatches: [Int]
}
