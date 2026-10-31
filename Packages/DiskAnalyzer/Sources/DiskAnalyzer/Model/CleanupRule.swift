import Darwin

/// What Oriel knows about one kind of folder (PLAN §7.10 item 19): where it is, what it is, how safe it is to clean up,
/// what happens afterwards, which apps use it, and the ways to clean it up, the recommended one first.
nonisolated struct CleanupRule: Sendable {
    enum Match: Sendable {
        /// A path: `~` for the home folder, `*` and `?` within a name as in the shell.
        case path(String)
        /// A folder with this name anywhere, with one of these names next to it (its project's file); anywhere at all
        /// when the set is empty.
        case name(String, besides: Set<String>)
        /// A folder anywhere that holds one of these names; with `only`, nothing but names from it: a tool's bare layout,
        /// not a project that happens to hold the name too.
        case holding(Set<String>, only: Set<String>? = nil)
    }

    var id: String
    var matches: [Match]
    var verdict: CleanupVerdict
    /// What it is.
    var summary: String
    /// What happens once it is gone.
    var afterwards: String?
    /// The apps that write to it, by bundle ID: quit them first.
    var apps: [String] = []
    var methods: @Sendable (CleanupFacts) -> [CleanupMethod]

    func matches(_ facts: CleanupFacts) -> Bool {
        matches.contains { match in
            switch match {
            case let .path(pattern):
                Self.path(facts.homeRelativePath, matches: pattern)
            case let .name(name, besides):
                facts.name == name && (besides.isEmpty || !besides.isDisjoint(with: facts.siblingNames))
            case let .holding(names, only):
                !names.isDisjoint(with: facts.names) && (only.map(facts.names.isSubset(of:)) ?? true)
            }
        }
    }

    /// Whether a path pattern matched: the folder is the tool's own place, not one that only looks like it by name.
    func matchesByPath(_ facts: CleanupFacts) -> Bool {
        matches.contains { match in
            guard case let .path(pattern) = match else { return false }
            return Self.path(facts.homeRelativePath, matches: pattern)
        }
    }

    /// Whether `path` (absolute, or from `~`) matches `pattern`, name by name.
    static func path(_ path: String, matches pattern: String) -> Bool {
        let names = path.split(separator: "/", omittingEmptySubsequences: true)
        let patterns = pattern.split(separator: "/", omittingEmptySubsequences: true)
        guard names.count == patterns.count, path.hasPrefix("/") == pattern.hasPrefix("/") else { return false }
        return zip(names, patterns).allSatisfy { name, pattern in
            pattern.contains("*") || pattern.contains("?") ? fnmatch(String(pattern), String(name), 0) == 0 : name == pattern
        }
    }
}
