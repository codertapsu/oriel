/// Where a volume lives, for its icon and the eject rules.
nonisolated enum VolumeKind: String, Sendable, Codable {
    /// The volume macOS started from (shown as Macintosh HD).
    case startup
    /// Another volume on an internal disk.
    case internalDisk = "internal"
    /// A USB, Thunderbolt or SD card volume, or a mounted disk image.
    case external
    /// A file server.
    case network

    var symbol: String {
        switch self {
        case .startup, .internalDisk: "internaldrive"
        case .external: "externaldrive"
        case .network: "server.rack"
        }
    }

    var title: String {
        switch self {
        case .startup: "Startup disk"
        case .internalDisk: "Internal"
        case .external: "External"
        case .network: "Network"
        }
    }

    /// Classifies a volume from what `URLResourceValues` says about it.
    static func of(isRoot: Bool, isLocal: Bool, isInternal: Bool?) -> VolumeKind {
        if isRoot {
            return .startup
        }
        if !isLocal {
            return .network
        }
        return isInternal == true ? .internalDisk : .external
    }
}
