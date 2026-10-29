/// Folder paths typed in Settings (`Screenshots/Oriel`, `/Oriel/`) as segments, without empty, `.` or `..` parts,
/// so a folder can never point above the place it is meant to be in.
public nonisolated enum UploadPath {
    public static func segments(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// `segments` joined with `/`.
    public static func joined(_ segments: [String]) -> String {
        segments.joined(separator: "/")
    }
}
