import Foundation

/// macOS's own volumes, read next to the data volume when a scan covers the whole startup volume (Settings → Count
/// macOS's own files one by one): the sealed system volume, read at `/`, and the helper volumes macOS mounts under
/// /System/Volumes in the same APFS container, entered from it (VM with the swap files, Update). Preboot is one block of
/// the space it uses: macOS grafts its cryptexes in from disk images that are APFS clones of each other, so listing its
/// files would count the same space two or three times (macOS 27.0.1, docs/os-quirks.md).
///
/// Read that way, the system volume's firmlinks are left out, since what they lead to is counted on the data volume, and
/// so are the volumes mounted on it that are not read: the data volume itself, devices, automounts.
nonisolated struct MacOSVolumes: Sendable, Equatable {
    /// Where the system volume is read.
    var systemPath = "/"
    /// The helper volumes read file by file.
    var helperMounts: Set<String>
    /// The helper volumes counted as one block each.
    var blockMounts: Set<String> = []
    /// The name of the folder that holds them in the scan.
    var displayName = "macOS"

    /// The startup container's helper volumes, Preboot as a block and the others read file by file.
    static func startup(helperMounts: Set<String>) -> MacOSVolumes {
        let blocks = helperMounts.filter { ($0 as NSString).lastPathComponent == "Preboot" }
        return MacOSVolumes(helperMounts: helperMounts.subtracting(blocks), blockMounts: blocks)
    }

    /// Folders at the top of the system volume that only steer path resolution (macOS 27.0.1); listed, they are empty.
    static let resolutionFolders: Set<String> = ["/.nofollow", "/.resolve", "/.vol"]

    /// Whether a folder of these volumes is kept: not a firmlink, an automount trigger or a folder that steers path
    /// resolution, and not a volume other than a helper volume.
    func keeps(_ entry: DirectoryEntry, at path: String) -> Bool {
        !entry.isFirmlink && !entry.isMountTrigger && !Self.resolutionFolders.contains(path)
            && (!entry.isMountPoint || helperMounts.contains(path))
    }
}
