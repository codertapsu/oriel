import Darwin
import Foundation

/// The mounted volumes and their capacity. Read when the window opens, when a volume mounts, unmounts or is renamed,
/// and after a scan or a file operation, never on a timer; off the main thread, because asking for the space available
/// for important use makes macOS work out what it could purge.
nonisolated enum VolumeService {
    static let keys: [URLResourceKey] = [
        .volumeLocalizedNameKey, .volumeLocalizedFormatDescriptionKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityForOpportunisticUsageKey, .volumeIsRemovableKey,
        .volumeIsEjectableKey, .volumeIsInternalKey, .volumeIsReadOnlyKey, .volumeIsBrowsableKey, .volumeIsLocalKey,
        .volumeIsRootFileSystemKey,
    ]

    /// The volumes Finder shows: the startup disk first, then internal, external and network ones, by name.
    static func mountedVolumes() -> [VolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        let order: [VolumeKind] = [.startup, .internalDisk, .external, .network]
        return urls.compactMap(info).sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.kind) ?? 0
            let right = order.firstIndex(of: rhs.kind) ?? 0
            return left != right ? left < right : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    static func info(for url: URL) -> VolumeInfo? {
        guard let values = try? url.resourceValues(forKeys: Set(keys)), let total = values.volumeTotalCapacity else { return nil }
        let isRoot = values.volumeIsRootFileSystem ?? (url.path == "/")
        let usage = VolumeUsage(
            total: Int64(total),
            available: Int64(values.volumeAvailableCapacity ?? 0),
            availableForImportantUsage: values.volumeAvailableCapacityForImportantUsage,
            availableForOpportunisticUsage: values.volumeAvailableCapacityForOpportunisticUsage
        )
        return VolumeInfo(
            path: url.path,
            name: values.volumeLocalizedName ?? url.lastPathComponent,
            format: values.volumeLocalizedFormatDescription ?? "",
            usage: usage,
            kind: VolumeKind.of(isRoot: isRoot, isLocal: values.volumeIsLocal ?? true, isInternal: values.volumeIsInternal),
            isReadOnly: values.volumeIsReadOnly ?? false,
            isEjectable: values.volumeIsEjectable ?? false,
            isRemovable: values.volumeIsRemovable ?? false,
            isBrowsable: values.volumeIsBrowsable ?? true
        )
    }

    /// The bytes used by the startup disk's sealed system and the helper volumes macOS mounts under
    /// `/System/Volumes` (Preboot, VM, Update…) in the same APFS container, the data volume left out. On APFS each
    /// volume's own use is `statfs`'s blocks minus its free blocks; the container's free space is shared.
    static func systemBytes() -> Int64 {
        guard let root = usedAndTotal("/") else { return 0 }
        var total = root.used
        let hidden = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: []) ?? []
        for url in hidden where url.path.hasPrefix("/System/Volumes/") && url.path != FirmlinkMap.dataVolume {
            // Volumes of other containers (the Apple silicon boot container's xarts, iSCPreboot, Hardware) differ in size.
            guard let volume = usedAndTotal(url.path), volume.total == root.total else { continue }
            total += volume.used
        }
        return total
    }

    private static func usedAndTotal(_ path: String) -> (used: Int64, total: Int64)? {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return nil }
        let block = Int64(info.f_bsize)
        let used = (Int64(info.f_blocks) - Int64(info.f_bfree)) * block
        return (max(0, used), Int64(info.f_blocks) * block)
    }

    /// The mount points of every volume, hidden ones included, for the safety rules.
    static func allMountPoints() -> Set<String> {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: []) ?? []
        return Set(urls.map(\.path))
    }

    /// The firmlinks of the startup volume, read from `/usr/share/firmlinks`.
    static func firmlinks() -> FirmlinkMap {
        guard let text = try? String(contentsOfFile: "/usr/share/firmlinks", encoding: .utf8) else { return .empty }
        return FirmlinkMap(parsing: text)
    }
}
