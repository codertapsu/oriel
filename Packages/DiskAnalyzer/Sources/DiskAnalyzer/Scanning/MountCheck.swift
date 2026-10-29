import Darwin

/// Which mounted volumes a scan may enter when crossing volumes is allowed: local, browsable ones the user mounted.
/// Never network shares (slow, and they may hang), automounts, nor the hidden volumes macOS mounts for itself
/// (simulator runtimes, cryptexes, device file systems), which are often disk images already counted as files.
nonisolated enum MountCheck {
    static func canCross(into path: String) -> Bool {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return false }
        return isCrossable(flags: UInt32(truncatingIfNeeded: info.f_flags))
    }

    static func isCrossable(flags: UInt32) -> Bool {
        flags & UInt32(MNT_LOCAL) != 0 && flags & UInt32(MNT_DONTBROWSE) == 0 && flags & UInt32(MNT_AUTOMOUNTED) == 0
    }
}
