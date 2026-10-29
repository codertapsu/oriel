/// A name that is free in the destination folder, the way Finder keeps both: "Report.pdf", then "Report 2.pdf",
/// "Report 3.pdf". A folder or a name without an extension gets the number at the end.
nonisolated enum UniqueName {
    static func name(for name: String, isFolder: Bool, isTaken: (String) -> Bool) -> String {
        guard isTaken(name) else { return name }
        let (stem, ext) = split(name, isFolder: isFolder)
        for number in 2 ... 9999 {
            let candidate = ext.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(ext)"
            if !isTaken(candidate) {
                return candidate
            }
        }
        return "\(stem) \(Int.random(in: 10000 ... 99_999_999))" + (ext.isEmpty ? "" : ".\(ext)")
    }

    private static func split(_ name: String, isFolder: Bool) -> (stem: String, ext: String) {
        guard !isFolder, let dot = name.lastIndex(of: "."), dot != name.startIndex else { return (name, "") }
        let ext = name[name.index(after: dot)...]
        guard !ext.isEmpty, !ext.contains(" ") else { return (name, "") }
        return (String(name[..<dot]), String(ext))
    }
}
