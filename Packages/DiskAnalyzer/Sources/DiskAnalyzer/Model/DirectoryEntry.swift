/// One item of a directory listing, as a `DirectoryReading` returns it: the raw facts, before the scan decides how
/// to count it.
nonisolated struct DirectoryEntry: Sendable, Equatable {
    enum Kind: UInt8, Sendable {
        case file, directory, symlink, special
    }

    var name: String
    var kind: Kind
    /// The volume's device number, with the inode the identity of a hard-linked file.
    var device: Int32 = 0
    var inode: UInt64 = 0
    var linkCount: UInt32 = 1
    var logicalSize: Int64 = 0
    var allocatedSize: Int64 = 0
    /// Seconds since 1970; 0 when not known.
    var created: Int64 = 0
    var modified: Int64 = 0
    var accessed: Int64 = 0
    /// `st_flags`: `UF_HIDDEN`, `SF_DATALESS`, `SF_FIRMLINK`…
    var fileFlags: UInt32 = 0
    /// `ATTR_CMNEXT_EXT_FLAGS`: `EF_MAY_SHARE_BLOCKS`, `EF_IS_PURGEABLE`…
    var extendedFlags: UInt64 = 0
    var isMountPoint = false
    /// An automount trigger (autofs), which must never be entered: that would mount something.
    var isMountTrigger = false
    /// An error the file system reported for this entry alone.
    var error: Int32 = 0

    // The st_flags and extended flags the scan reads, from <sys/stat.h> and <sys/attr.h>.
    static let hiddenFlag: UInt32 = 0x0000_8000
    static let firmlinkFlag: UInt32 = 0x0080_0000
    static let datalessFlag: UInt32 = 0x4000_0000
    static let mayShareBlocks: UInt64 = 0x01
    static let isPurgeable: UInt64 = 0x08

    var isHidden: Bool {
        name.hasPrefix(".") || fileFlags & Self.hiddenFlag != 0
    }

    var isDataless: Bool {
        fileFlags & Self.datalessFlag != 0
    }

    var isFirmlink: Bool {
        fileFlags & Self.firmlinkFlag != 0
    }
}
