import Darwin

/// Why a folder could not be read, from the error opening it gave. Full Disk Access lifts macOS's privacy protection,
/// not a folder's permissions, so with it granted folders can still be unreadable (docs/os-quirks.md).
nonisolated enum UnreadableReason: Sendable, Equatable {
    /// `EACCES`: its permissions let only its owner in: macOS, one of macOS's own accounts, or another user. An
    /// administrator can read it (`ElevatedRead`).
    case needsAdministrator
    /// `EPERM`: macOS protects it. Privacy protection gives way to Full Disk Access; System Integrity Protection keeps it
    /// from every app, an administrator's included.
    case protectedByMacOS
    /// Any other error: the disk failed, or a file system stopped answering.
    case other

    init(error: Int32) {
        switch error {
        case EACCES: self = .needsAdministrator
        case EPERM: self = .protectedByMacOS
        default: self = .other
        }
    }

    init(flags: ScanNodeFlags) {
        if flags.contains(.needsAdministrator) {
            self = .needsAdministrator
        } else if flags.contains(.protectedByMacOS) {
            self = .protectedByMacOS
        } else {
            self = .other
        }
    }

    /// The flags of a folder that could not be read for this reason.
    var flags: ScanNodeFlags {
        switch self {
        case .needsAdministrator: [.unreadable, .needsAdministrator]
        case .protectedByMacOS: [.unreadable, .protectedByMacOS]
        case .other: .unreadable
        }
    }

    /// Every flag a reason sets, to clear them all before setting one.
    static let allFlags: ScanNodeFlags = [.unreadable, .needsAdministrator, .protectedByMacOS]
}
