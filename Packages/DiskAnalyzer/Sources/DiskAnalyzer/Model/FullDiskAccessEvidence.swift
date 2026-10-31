/// What a scan says about Full Disk Access, without asking macOS (CLAUDE.md rule 8) or reading anything for the purpose:
/// only Full Disk Access opens Safari's, Mail's and Messages' folders in the home folder, so a scan that read one of them
/// has it, and one macOS refused them to has not. With it, every folder macOS still refuses is closed to every app, which
/// is what the notes then say instead of asking for Full Disk Access again.
nonisolated enum FullDiskAccessEvidence {
    static let folders = ["Library/Safari", "Library/Mail", "Library/Messages"]

    /// True when the scan read one of `folders`, false when macOS refused it them, nil when it held none of them.
    static func isGranted(in tree: ScanTree, home: String) -> Bool? {
        var refused = false
        for folder in folders {
            guard let node = tree.index(ofPath: home + "/" + folder), !tree[node].flags.contains(.excluded) else { continue }
            let flags = tree[node].flags
            if flags.contains(.protectedByMacOS) {
                refused = true
            } else if !flags.contains(.unreadable) {
                return true
            }
        }
        return refused ? false : nil
    }
}
