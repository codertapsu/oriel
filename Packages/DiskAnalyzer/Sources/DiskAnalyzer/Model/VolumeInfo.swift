import Foundation

/// A mounted volume, for the sidebar, the volume overview and `oriel disk volumes`.
nonisolated struct VolumeInfo: Sendable, Equatable, Identifiable {
    /// Where it is mounted: `/` for the startup volume.
    var path: String
    var name: String
    /// "APFS", "ExFAT", "SMB (OS X)"…
    var format: String
    var usage: VolumeUsage
    var kind: VolumeKind
    var isReadOnly = false
    var isEjectable = false
    var isRemovable = false
    var isBrowsable = true

    var id: String {
        path
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Whether Oriel offers Eject: never for the startup disk or another internal one.
    var canEject: Bool {
        kind != .startup && kind != .internalDisk && (isEjectable || isRemovable || kind == .network)
    }

    /// Whether the volume can have local Time Machine snapshots (APFS, local, writable). The startup volume's system
    /// part is read-only, but its snapshots are of the data volume, which `tmutil` reaches through `/`.
    var canHaveLocalSnapshots: Bool {
        format.localizedCaseInsensitiveContains("APFS") && kind != .network && (kind == .startup || !isReadOnly)
    }
}
