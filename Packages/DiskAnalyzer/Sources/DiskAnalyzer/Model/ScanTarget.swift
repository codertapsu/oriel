/// What a scan reads and how it presents it. Scanning the startup volume reads its data volume, where every writable
/// file lives, so nothing is counted twice through the firmlinks, and adds the sealed system as one block.
nonisolated struct ScanTarget: Sendable, Equatable {
    /// The folder or volume the user chose.
    var requestedPath: String
    /// The folder that is read.
    var scanPath: String
    var displayName: String
    var firmlinks: FirmlinkMap
    /// The volume, when the whole of it is scanned; its used space decides the system and "Other space" blocks.
    var volume: VolumeInfo?

    var isStartupVolume: Bool {
        volume?.kind == .startup
    }

    /// - Parameters:
    ///   - path: the chosen folder, standardized.
    ///   - volumes: the mounted volumes, to tell a volume's root from a folder.
    ///   - dataVolumeExists: whether `/System/Volumes/Data` is there (it is on every Mac running macOS 10.15 or later).
    static func resolve(
        path: String,
        volumes: [VolumeInfo],
        dataVolumeExists: Bool,
        firmlinks: FirmlinkMap
    ) -> ScanTarget {
        let path = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
        if let volume = volumes.first(where: { $0.path == path }) {
            let scanPath = volume.kind == .startup && dataVolumeExists ? FirmlinkMap.dataVolume : path
            return ScanTarget(requestedPath: path, scanPath: scanPath, displayName: volume.name, firmlinks: firmlinks, volume: volume)
        }
        let name = path == "/" ? "/" : String(path.split(separator: "/").last ?? Substring(path))
        return ScanTarget(requestedPath: path, scanPath: path, displayName: name, firmlinks: firmlinks, volume: nil)
    }
}
