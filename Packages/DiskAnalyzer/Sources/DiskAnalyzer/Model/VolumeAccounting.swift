/// Makes a scan of a whole volume add up to the volume's used space. The startup volume's sealed system (and the
/// helper volumes Preboot, VM and Update) is one "macOS (system)" block rather than files, and whatever no scanned
/// file accounts for — local snapshots, other volumes of the same APFS container, unreadable folders, file-system
/// overhead — is one "Other space" block.
nonisolated enum VolumeAccounting {
    struct Blocks: Equatable, Sendable {
        var system: Int64
        var unaccounted: Int64
    }

    /// Below this, "Other space" is noise and is left out.
    static let minimumUnaccounted: Int64 = 100_000_000

    /// `volumeUsed` is the container's used space, `scanned` what the scan counted, `system` the system volumes' used
    /// space (0 for any volume but the startup one). Clones counted at full size can make `scanned` exceed what is
    /// used; there is then no "Other space".
    static func blocks(volumeUsed: Int64, scanned: Int64, system: Int64) -> Blocks {
        let system = max(0, system)
        let rest = volumeUsed - scanned - system
        let unaccounted = rest >= max(minimumUnaccounted, volumeUsed / 200) ? rest : 0
        return Blocks(system: system, unaccounted: unaccounted)
    }
}
