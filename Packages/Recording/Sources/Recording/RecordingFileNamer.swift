import Foundation

/// Names finished recordings and the files exported from them. Pure apart from the existence check it is given.
nonisolated enum RecordingFileNamer {
    /// `Oriel Recording 2026-10-29 at 14.05.09`, the way macOS names screen recordings.
    static func baseName(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let time = String(format: "%02d.%02d.%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        return "Oriel Recording \(day) at \(time)"
    }

    /// `folder/<baseName>.<ext>`, or `<baseName> 2.<ext>`, `<baseName> 3.<ext>` … when that exists.
    static func uniqueURL(
        in folder: URL,
        baseName: String,
        pathExtension: String,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        var candidate = folder.appending(path: "\(baseName).\(pathExtension)", directoryHint: .notDirectory)
        var number = 2
        while exists(candidate) {
            candidate = folder.appending(path: "\(baseName) \(number).\(pathExtension)", directoryHint: .notDirectory)
            number += 1
        }
        return candidate
    }

    /// A file next to `movie` named after it with `suffix`, e.g. `… (CFR).mp4` or `….gif`.
    static func sibling(
        of movie: URL,
        suffix: String = "",
        pathExtension: String,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let base = movie.deletingPathExtension().lastPathComponent + suffix
        return uniqueURL(in: movie.deletingLastPathComponent(), baseName: base, pathExtension: pathExtension, exists: exists)
    }
}
