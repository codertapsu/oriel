import Foundation

/// Items named with a version, as tools and IDEs name a folder per version they ran (`9.1.0`, `gradle-8.5-bin`,
/// `AndroidStudio2025.3.2`): grouped by the rest of the name, the newest of each group is in use and the others are left
/// over (PLAN §7.10 item 19). A version has at least two numbers joined by dots. Pure.
nonisolated enum VersionedNames {
    /// The name with its version taken out, and the version's numbers; nil for a name without one.
    static func parse(_ name: String) -> (stem: String, version: [Int])? {
        guard let range = name.range(of: #"\d+(\.\d+)+"#, options: .regularExpression) else { return nil }
        let version = name[range].split(separator: ".").compactMap { Int($0) }
        return (name.replacingCharacters(in: range, with: "#"), version)
    }

    /// Every item but the newest of each group of two or more with the same stem.
    static func older(among items: [CleanupFacts.Child]) -> [CleanupFacts.Child] {
        groups(of: items).flatMap { $0.dropLast() }
    }

    /// The newest item of each group of two or more.
    static func newest(among items: [CleanupFacts.Child]) -> [CleanupFacts.Child] {
        groups(of: items).compactMap(\.last)
    }

    /// The groups of two or more, each oldest version first.
    private static func groups(of items: [CleanupFacts.Child]) -> [[CleanupFacts.Child]] {
        var groups: [String: [(item: CleanupFacts.Child, version: [Int])]] = [:]
        for item in items {
            if let parsed = parse(item.name) {
                groups[parsed.stem, default: []].append((item, parsed.version))
            }
        }
        return groups.values.filter { $0.count > 1 }.map { group in
            group.sorted { $0.version.lexicographicallyPrecedes($1.version) }.map(\.item)
        }
    }
}
