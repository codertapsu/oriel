/// What one directory adds to a scan, decided from its raw entries: which items are kept one by one, the smaller files
/// counted together, the folders to read next, and the totals. Pure, so the counting rules are tested without a
/// file system.
///
/// - Files at or above the threshold are kept; smaller files, symlinks and devices are summed into one aggregate.
/// - A file with several hard links is counted once (`isFirstLink`); its other links get no size.
/// - Symlinks are never followed. Firmlinks, automount triggers, folders that are only in the cloud, excluded folders
///   and, unless crossing is allowed, other volumes are listed but not entered.
nonisolated struct DirectoryDigest: Sendable, Equatable {
    struct Item: Sendable, Equatable {
        var name: String
        var kind: ScanNodeKind
        var size: Int64 = 0
        var logicalSize: Int64 = 0
        var created = ScanNode.unknownDate
        var modified = ScanNode.unknownDate
        var accessed = ScanNode.unknownDate
        var category: FileCategory = .other
        var flags: ScanNodeFlags = []
        /// Whether the scan reads it next.
        var descends = false
        /// The category the files inside take: a package's, so an app counts as an application.
        var inheritedCategory: FileCategory?
        /// Another volume, entered because crossing is allowed.
        var crossesVolume = false
    }

    struct SmallFiles: Sendable, Equatable {
        var count = 0
        var size: Int64 = 0
        var logicalSize: Int64 = 0
        var newest = ScanNode.unknownDate

        mutating func add(_ entry: DirectoryEntry, size: Int64, logicalSize: Int64) {
            count += 1
            self.size += size
            self.logicalSize += logicalSize
            newest = max(newest, ScanNode.encode(secondsSince1970: entry.modified))
        }
    }

    var items: [Item] = []
    var small = SmallFiles()
    var categoryTotals = CategoryTotals()
    var cloudOnlyFiles = 0
    var cloudOnlyBytes: Int64 = 0
    var duplicateLinks = 0
    /// Entries the file system reported an error for, which are left out.
    var entryErrors = 0

    /// Folds `entries`, the contents of the directory at `parentPath`, into what the scan keeps.
    static func make(
        entries: [DirectoryEntry],
        parentPath: String,
        inheritedCategory: FileCategory?,
        options: ScanOptions,
        categories: inout FileCategoryCache,
        isFirstLink: (Int32, UInt64) -> Bool,
        canCrossInto: (String) -> Bool = { _ in false }
    ) -> DirectoryDigest {
        var digest = DirectoryDigest()
        for entry in entries {
            guard entry.error == 0 else {
                digest.entryErrors += 1
                continue
            }
            if !options.includesHiddenFiles, entry.isHidden {
                continue
            }
            switch entry.kind {
            case .directory:
                let path = childPath(parentPath, entry.name)
                digest.items.append(folder(
                    entry,
                    path: path,
                    inherited: inheritedCategory,
                    options: options,
                    categories: &categories,
                    canCrossInto: canCrossInto
                ))
            case .file:
                digest.addFile(entry, inherited: inheritedCategory, options: options, categories: &categories, isFirstLink: isFirstLink)
            case .symlink, .special:
                digest.small.add(entry, size: entry.allocatedSize, logicalSize: entry.logicalSize)
            }
        }
        return digest
    }

    static func childPath(_ parent: String, _ name: String) -> String {
        parent == "/" ? "/" + name : parent + "/" + name
    }

    private static func folder(
        _ entry: DirectoryEntry,
        path: String,
        inherited: FileCategory?,
        options: ScanOptions,
        categories: inout FileCategoryCache,
        canCrossInto: (String) -> Bool
    ) -> Item {
        let isPackage = categories.isPackage(entry.name)
        var item = Item(name: entry.name, kind: isPackage ? .package : .folder)
        item.created = ScanNode.encode(secondsSince1970: entry.created)
        item.modified = ScanNode.encode(secondsSince1970: entry.modified)
        item.accessed = ScanNode.encode(secondsSince1970: entry.accessed)
        if entry.isHidden {
            item.flags.insert(.hidden)
        }
        let packageCategory = isPackage ? (inherited ?? categories.category(of: entry.name)) : inherited
        item.category = isPackage ? packageCategory ?? .other : .other
        item.inheritedCategory = packageCategory
        if entry.isMountTrigger {
            item.flags.insert(.mountPoint)
        } else if entry.isFirmlink {
            item.flags.insert(.firmlink)
        } else if entry.isMountPoint {
            item.flags.insert(.mountPoint)
            item.crossesVolume = options.crossesVolumes && canCrossInto(path)
            item.descends = item.crossesVolume
        } else if entry.isDataless {
            item.flags.insert(.cloudOnly)
        } else if options.exclusions.excludes(path: path, name: entry.name) {
            item.flags.insert(.excluded)
        } else {
            item.descends = true
        }
        return item
    }

    private mutating func addFile(
        _ entry: DirectoryEntry,
        inherited: FileCategory?,
        options: ScanOptions,
        categories: inout FileCategoryCache,
        isFirstLink: (Int32, UInt64) -> Bool
    ) {
        var flags: ScanNodeFlags = []
        var size = entry.allocatedSize
        var logical = entry.logicalSize
        if entry.isHidden {
            flags.insert(.hidden)
        }
        if entry.isDataless {
            flags.insert(.cloudOnly)
            cloudOnlyFiles += 1
            cloudOnlyBytes += entry.logicalSize
        }
        if entry.extendedFlags & DirectoryEntry.mayShareBlocks != 0 {
            flags.insert(.sharesBlocks)
        }
        if entry.extendedFlags & DirectoryEntry.isPurgeable != 0 {
            flags.insert(.purgeable)
        }
        if entry.linkCount > 1 {
            flags.insert(.hardLink)
            if !isFirstLink(entry.device, entry.inode) {
                flags.insert(.duplicateLink)
                duplicateLinks += 1
                size = 0
                logical = 0
            }
        }
        let category = inherited ?? categories.category(of: entry.name)
        categoryTotals.add(category, bytes: size)
        let keeps = size >= options.smallFileThreshold || (flags.contains(.cloudOnly) && logical >= options.smallFileThreshold)
        guard keeps else {
            small.add(entry, size: size, logicalSize: logical)
            return
        }
        var item = Item(name: entry.name, kind: .file, size: size, logicalSize: logical, category: category, flags: flags)
        item.created = ScanNode.encode(secondsSince1970: entry.created)
        item.modified = ScanNode.encode(secondsSince1970: entry.modified)
        item.accessed = ScanNode.encode(secondsSince1970: entry.accessed)
        items.append(item)
    }
}
