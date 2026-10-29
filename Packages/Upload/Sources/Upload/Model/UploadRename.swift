/// The name a file gets when its own is taken: "Shot.png", "Shot 2.png", "Shot 3.png"…, the way Finder and the
/// capture file names count.
nonisolated enum UploadRename {
    /// `path` with its last element numbered; number 1 is the name itself.
    static func numbered(_ path: [String], _ number: Int) -> [String] {
        guard number > 1, let last = path.last else { return path }
        let name = if let dot = last.lastIndex(of: "."), dot != last.startIndex {
            "\(last[..<dot]) \(number)\(last[dot...])"
        } else {
            "\(last) \(number)"
        }
        return path.dropLast() + [name]
    }
}
