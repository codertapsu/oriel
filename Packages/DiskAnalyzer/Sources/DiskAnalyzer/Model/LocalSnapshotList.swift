import Foundation

/// Reads what `tmutil` prints about local Time Machine snapshots. `listlocalsnapshots /` prints a header line
/// ("Snapshots for disk /:") and one `com.apple.TimeMachine.2026-10-29-091756.local` per snapshot; `thinlocalsnapshots`
/// prints "Thinned local snapshots:" and one date per snapshot it removed.
nonisolated enum LocalSnapshotList {
    struct Snapshot: Sendable, Equatable {
        var name: String
        var date: Date?
    }

    static func snapshots(fromList output: String) -> [Snapshot] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let name = line.trimmingCharacters(in: .whitespaces)
            guard name.hasPrefix("com.apple."), !name.hasSuffix(":") else { return nil }
            return Snapshot(name: name, date: date(in: name))
        }
    }

    /// How many snapshots a thinning removed.
    static func thinnedCount(fromThin output: String) -> Int {
        output.split(whereSeparator: \.isNewline).count { line in
            date(in: line.trimmingCharacters(in: .whitespaces)) != nil
        }
    }

    /// The date in a snapshot name or line (`YYYY-MM-DD-HHMMSS`), in this Mac's time zone, as `tmutil` writes it.
    static func date(in text: String) -> Date? {
        guard let match = text.firstMatch(of: /(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})/) else { return nil }
        var components = DateComponents()
        components.year = Int(match.1)
        components.month = Int(match.2)
        components.day = Int(match.3)
        components.hour = Int(match.4)
        components.minute = Int(match.5)
        components.second = Int(match.6)
        components.timeZone = .current
        return Calendar(identifier: .gregorian).date(from: components)
    }
}
