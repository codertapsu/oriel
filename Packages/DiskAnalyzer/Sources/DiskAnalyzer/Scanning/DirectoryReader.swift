/// Reads directories for a scan: in bulk where the file system supports it, else through `FileManager`. One per
/// scanning thread.
final nonisolated class DirectoryReader {
    /// Which reader to use; tests pin the fallback to compare the two.
    enum Mode: Sendable {
        case automatic, foundationOnly
    }

    private let bulk = BulkDirectoryReader()
    private let mode: Mode

    init(mode: Mode = .automatic) {
        self.mode = mode
    }

    func read(_ path: String) -> DirectoryReadResult {
        if mode == .automatic, let result = bulk.read(path) {
            return result
        }
        return FoundationDirectoryReader.read(path)
    }
}
