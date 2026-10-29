import Foundation

/// Chapters as YouTube-style timestamps, one per line ("00:00 Start"), for a video description (PLAN §17). Pure.
nonisolated enum ChapterTimestamps {
    /// YouTube shows chapters only when there are at least this many.
    static let youTubeMinimumCount = 3
    /// YouTube shows chapters only when each lasts at least this long, in seconds.
    static let youTubeMinimumLength = 10.0

    /// `00:00 Start`, `01:23 Demo` …, in whole seconds rounded down; `0:00:00` style once the movie reaches an hour.
    static func text(for chapters: [ExportedChapter]) -> String {
        let usesHours = (chapters.last?.end ?? 0) >= 3600
        return chapters.map { "\(timestamp($0.start, usesHours: usesHours)) \($0.title)" }.joined(separator: "\n")
    }

    /// `MM:SS`, or `H:MM:SS` when `usesHours`.
    static func timestamp(_ seconds: Double, usesHours: Bool) -> String {
        let total = seconds.isFinite ? Int(max(seconds, 0).rounded(.down)) : 0
        let hours = total / 3600
        let minutes = total / 60 % 60
        let rest = total % 60
        if usesHours {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%02d:%02d", total / 60, rest)
    }

    /// Why YouTube would not show these chapters, if it would not; empty when it would.
    static func youTubeProblems(_ chapters: [ExportedChapter]) -> [String] {
        var problems: [String] = []
        if chapters.count < youTubeMinimumCount {
            problems.append("YouTube shows chapters only when there are at least three.")
        }
        if chapters.contains(where: { $0.duration < youTubeMinimumLength }) {
            problems.append("YouTube shows chapters only when each is at least 10 seconds long.")
        }
        return problems
    }
}
