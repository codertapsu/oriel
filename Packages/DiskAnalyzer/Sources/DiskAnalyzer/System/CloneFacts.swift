import Darwin

/// What APFS says about one file's sharing: how many of its bytes deleting it would free (`ATTR_CMNEXT_PRIVATESIZE`:
/// bytes not shared with a clone or a snapshot), the id of its data (clones share it) and whether it shares all of its
/// blocks. One `getattrlist` per file, for the inspector and the duplicate finder; too slow to ask during a scan.
nonisolated struct CloneFacts: Sendable, Equatable {
    var privateSize: Int64?
    var cloneID: UInt64?
    var sharesAllBlocks = false

    static func of(_ path: String) -> CloneFacts? {
        var list = attrlist()
        list.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        list.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
        list.forkattr = attrgroup_t(ATTR_CMNEXT_PRIVATESIZE) | attrgroup_t(ATTR_CMNEXT_CLONEID) | attrgroup_t(ATTR_CMNEXT_EXT_FLAGS)
        var buffer = [UInt8](repeating: 0, count: 128)
        let result = buffer.withUnsafeMutableBytes { raw in
            getattrlist(path, &list, raw.baseAddress, raw.count, UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW))
        }
        guard result == 0 else { return nil }
        return buffer.withUnsafeBytes { raw -> CloneFacts? in
            guard let base = raw.baseAddress else { return nil }
            var field = base + MemoryLayout<UInt32>.size
            let returned = field.loadUnaligned(as: attribute_set_t.self)
            field += MemoryLayout<attribute_set_t>.size
            var facts = CloneFacts()
            if returned.forkattr & attrgroup_t(ATTR_CMNEXT_PRIVATESIZE) != 0 {
                facts.privateSize = field.loadUnaligned(as: Int64.self)
                field += 8
            }
            if returned.forkattr & attrgroup_t(ATTR_CMNEXT_CLONEID) != 0 {
                facts.cloneID = field.loadUnaligned(as: UInt64.self)
                field += 8
            }
            if returned.forkattr & attrgroup_t(ATTR_CMNEXT_EXT_FLAGS) != 0 {
                facts.sharesAllBlocks = field.loadUnaligned(as: UInt64.self) & 0x40 != 0
            }
            return facts
        }
    }
}
