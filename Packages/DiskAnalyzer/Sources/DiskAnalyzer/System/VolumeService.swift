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
    /// `/System/Volumes` (Preboot, VM, Update…) in the same APFS container, the data volume left out.
    static func systemBytes() -> Int64 {
        (["/"] + helperVolumeMounts()).reduce(0) { $0 + (spaceUsed($1) ?? 0) }
    }

    /// The space the volume mounted at `path` takes itself, as `df` shows it (`ATTR_VOL_SPACEUSED`). On APFS `statfs`
    /// answers for the whole container, the same for every volume in it (macOS 27.0.1, docs/os-quirks.md).
    static func spaceUsed(_ path: String) -> Int64? {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.volattr = attrgroup_t(ATTR_VOL_INFO) | attrgroup_t(ATTR_VOL_SPACEUSED)
        // The length, then the value, packed at 4-byte alignment.
        var buffer = [UInt8](repeating: 0, count: 16)
        let status = buffer.withUnsafeMutableBytes { getattrlist(path, &list, $0.baseAddress, $0.count, 0) }
        guard status == 0 else { return nil }
        return buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
    }

    /// The mount points of the helper volumes macOS keeps under `/System/Volumes` in the startup volume's APFS container
    /// (Preboot, VM, Update…), the data volume left out. `statfs`'s totals are the container's, so they tell the
    /// volumes of this container from those of another.
    static func helperVolumeMounts() -> Set<String> {
        guard let root = containerSize("/") else { return [] }
        let hidden = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: []) ?? []
        return Set(hidden.map(\.path).filter { path in
            // Volumes of other containers (the Apple silicon boot container's xarts, iSCPreboot, Hardware) differ in size.
            path.hasPrefix("/System/Volumes/") && path != FirmlinkMap.dataVolume && containerSize(path) == root
        })
    }

    /// The size `statfs` gives, which on APFS is the container's.
    private static func containerSize(_ path: String) -> Int64? {
        var info = statfs()
        guard statfs(path, &info) == 0 else { return nil }
        return Int64(info.f_blocks) * Int64(info.f_bsize)
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
