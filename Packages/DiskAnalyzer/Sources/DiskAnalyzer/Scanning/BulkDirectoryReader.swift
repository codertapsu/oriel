import Darwin

/// Reads a directory with `getattrlistbulk(2)`: one system call returns the attributes of many entries at once, which
/// makes a scan several times faster than `readdir` plus `lstat`. The attributes asked for are what the scan counts:
/// type, sizes (allocated and logical), dates, flags (hidden, dataless, firmlink), inode and link count (hard links),
/// mount status, and APFS's extended flags (clones, purgeable files).
///
/// Not thread-safe: each scanning thread has its own, with its own buffer.
final nonisolated class BulkDirectoryReader {
    private static let capacity = 256 * 1024
    private let buffer = UnsafeMutableRawPointer.allocate(byteCount: BulkDirectoryReader.capacity, alignment: 16)
    /// Set once a volume refused the extended attributes; they are then left out.
    private var omitsExtendedAttributes = false

    deinit {
        buffer.deallocate()
    }

    /// The directory's entries, or nil when the file system does not support bulk reads (the caller falls back).
    func read(_ path: String) -> DirectoryReadResult? {
        let descriptor = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return .unreadable(errno) }
        defer { close(descriptor) }
        var entries: [DirectoryEntry] = []
        var list = attributes()
        while true {
            let count = getattrlistbulk(descriptor, &list, buffer, Self.capacity, options)
            if count == 0 {
                return .listed(entries, error: 0)
            }
            if count < 0 {
                let error = errno
                if error == EINTR {
                    continue
                }
                if entries.isEmpty, error == EINVAL || error == ENOTSUP {
                    if !omitsExtendedAttributes {
                        // Some file systems take the basic attributes but not the extended ones: try again without.
                        omitsExtendedAttributes = true
                        list = attributes()
                        lseek(descriptor, 0, SEEK_SET)
                        continue
                    }
                    return nil
                }
                return .listed(entries, error: error)
            }
            parse(count: Int(count), into: &entries)
        }
    }

    private var options: UInt64 {
        UInt64(FSOPT_RETURN_REALDEV) | (omitsExtendedAttributes ? 0 : UInt64(FSOPT_ATTR_CMN_EXTENDED))
    }

    private func attributes() -> attrlist {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS) | attrgroup_t(ATTR_CMN_NAME) | attrgroup_t(ATTR_CMN_ERROR)
            | attrgroup_t(ATTR_CMN_DEVID) | attrgroup_t(ATTR_CMN_OBJTYPE) | attrgroup_t(ATTR_CMN_CRTIME)
            | attrgroup_t(ATTR_CMN_MODTIME) | attrgroup_t(ATTR_CMN_ACCTIME) | attrgroup_t(ATTR_CMN_FLAGS)
            | attrgroup_t(ATTR_CMN_FILEID)
        list.dirattr = attrgroup_t(ATTR_DIR_MOUNTSTATUS)
        list.fileattr = attrgroup_t(ATTR_FILE_LINKCOUNT) | attrgroup_t(ATTR_FILE_TOTALSIZE) | attrgroup_t(ATTR_FILE_ALLOCSIZE)
        list.forkattr = omitsExtendedAttributes ? 0 : attrgroup_t(ATTR_CMNEXT_EXT_FLAGS)
        return list
    }

    /// Walks `count` packed entries. Each starts with its length; its attributes follow in the order of their bits,
    /// each 4-byte aligned, and only those `returned` lists are present.
    private func parse(count: Int, into entries: inout [DirectoryEntry]) {
        var entry = UnsafeRawPointer(buffer)
        for _ in 0 ..< count {
            let length = Int(entry.loadUnaligned(as: UInt32.self))
            guard length > 0 else { return }
            if let parsed = Self.parseEntry(entry) {
                entries.append(parsed)
            }
            entry += length
        }
    }

    private static func parseEntry(_ start: UnsafeRawPointer) -> DirectoryEntry? {
        var field = start + MemoryLayout<UInt32>.size
        let returned = field.loadUnaligned(as: attribute_set_t.self)
        field += MemoryLayout<attribute_set_t>.size
        let common = returned.commonattr
        var error: Int32 = 0
        if common & attrgroup_t(ATTR_CMN_ERROR) != 0 {
            error = Int32(bitPattern: field.loadUnaligned(as: UInt32.self))
            field += 4
        }
        guard common & attrgroup_t(ATTR_CMN_NAME) != 0 else { return nil }
        let reference = field.loadUnaligned(as: attrreference_t.self)
        let nameBytes = UnsafeRawBufferPointer(
            start: field + Int(reference.attr_dataoffset), count: max(0, Int(reference.attr_length) - 1)
        )
        field += MemoryLayout<attrreference_t>.size
        // Every file system macOS mounts hands names over as UTF-8; one that is not is reported, not guessed at.
        let name = String(validating: nameBytes, as: UTF8.self)
        var result = DirectoryEntry(name: name ?? "", kind: .special, error: name == nil ? EILSEQ : error)
        if common & attrgroup_t(ATTR_CMN_DEVID) != 0 {
            result.device = field.loadUnaligned(as: Int32.self)
            field += 4
        }
        if common & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 {
            result.kind = kind(field.loadUnaligned(as: UInt32.self))
            field += 4
        }
        result.created = seconds(&field, if: common & attrgroup_t(ATTR_CMN_CRTIME) != 0)
        result.modified = seconds(&field, if: common & attrgroup_t(ATTR_CMN_MODTIME) != 0)
        result.accessed = seconds(&field, if: common & attrgroup_t(ATTR_CMN_ACCTIME) != 0)
        if common & attrgroup_t(ATTR_CMN_FLAGS) != 0 {
            result.fileFlags = field.loadUnaligned(as: UInt32.self)
            field += 4
        }
        if common & attrgroup_t(ATTR_CMN_FILEID) != 0 {
            result.inode = field.loadUnaligned(as: UInt64.self)
            field += 8
        }
        if returned.dirattr & attrgroup_t(ATTR_DIR_MOUNTSTATUS) != 0 {
            let status = field.loadUnaligned(as: UInt32.self)
            result.isMountPoint = status & UInt32(DIR_MNTSTATUS_MNTPOINT) != 0
            result.isMountTrigger = status & UInt32(DIR_MNTSTATUS_TRIGGER) != 0
            field += 4
        }
        parseFile(&field, returned: returned, into: &result)
        if returned.forkattr & attrgroup_t(ATTR_CMNEXT_EXT_FLAGS) != 0 {
            result.extendedFlags = field.loadUnaligned(as: UInt64.self)
        }
        return result
    }

    private static func parseFile(_ field: inout UnsafeRawPointer, returned: attribute_set_t, into result: inout DirectoryEntry) {
        let file = returned.fileattr
        if file & attrgroup_t(ATTR_FILE_LINKCOUNT) != 0 {
            result.linkCount = field.loadUnaligned(as: UInt32.self)
            field += 4
        }
        if file & attrgroup_t(ATTR_FILE_TOTALSIZE) != 0 {
            result.logicalSize = field.loadUnaligned(as: Int64.self)
            field += 8
        }
        if file & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 {
            result.allocatedSize = field.loadUnaligned(as: Int64.self)
            field += 8
        }
    }

    private static func seconds(_ field: inout UnsafeRawPointer, if present: Bool) -> Int64 {
        guard present else { return 0 }
        let time = field.loadUnaligned(as: timespec.self)
        field += MemoryLayout<timespec>.size
        return Int64(time.tv_sec)
    }

    private static func kind(_ type: UInt32) -> DirectoryEntry.Kind {
        switch type {
        case VREG.rawValue: .file
        case VDIR.rawValue: .directory
        case VLNK.rawValue: .symlink
        default: .special
        }
    }
}
