import Foundation

/// Sample Process…: `/usr/bin/sample <pid> 3 -file <report>`, which records the process's call stacks for three seconds
/// into a text report, as Activity Monitor's Sample Process does. The user's own processes only.
nonisolated enum SampleReport {
    static let tool = URL(fileURLWithPath: "/usr/bin/sample")
    static let seconds = 3

    /// Where reports go: a folder in the temporary directory, which macOS empties after a few days.
    static var folder: URL {
        FileManager.default.temporaryDirectory.appending(path: "Oriel Samples", directoryHint: .isDirectory)
    }

    /// "Safari-812-2026-10-29-143012.txt"; slashes and colons, which Finder cannot show, become dashes.
    static func fileName(for name: String, pid: Int32, at date: Date) -> String {
        let safe = String(name.map { "/:".contains($0) ? "-" : $0 }.prefix(60))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "\(safe)-\(pid)-\(formatter.string(from: date)).txt"
    }

    static func arguments(pid: Int32, file: URL) -> [String] {
        [String(pid), String(seconds), "-file", file.path(percentEncoded: false)]
    }

    /// Records the report and returns where it is.
    static func record(pid: Int32, name: String) async throws -> URL {
        let folder = folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: fileName(for: name, pid: pid, at: Date()))
        // Symbolicating a large app can take longer than the sampling itself.
        let result = try await CommandRunner.run(tool, arguments(pid: pid, file: file), timeout: .seconds(seconds + 60))
        guard result.status == 0, FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            let message = result.errorText.isEmpty ? result.text.trimmingCharacters(in: .whitespacesAndNewlines) : result.errorText
            throw SampleError(message: message.isEmpty ? "sample stopped without a report." : message)
        }
        return file
    }

    struct SampleError: LocalizedError, Sendable {
        let message: String

        var errorDescription: String? {
            message
        }
    }
}
