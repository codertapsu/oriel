/// What one directory adds to a scan, decided from its raw entries: which items are kept one by one, the smaller files
/// counted together, the folders to read next, and the totals. Pure, so the counting rules are tested without a
/// file system.
///
/// - Files at or above the threshold are kept; smaller files, symlinks and devices are summed into one aggregate.
/// - A file with several hard links is counted once. Which of its links that is depends on what the rest of the scan
///   counted, so they wait in `links` until the tree counts them (`ScanTree.merge`): the first gets the size, every
///   other link none.
/// - Symlinks are never followed. Firmlinks, automount triggers, folders that are only in the cloud, excluded folders
///   and, unless crossing is allowed, other volumes are listed but not entered.
/// - On macOS's own volumes (`MacOSVolumes`), firmlinks, automount triggers and volumes other than the helper volumes
///   are left out altogether, the helper volumes are entered, and everything is marked `macOSVolume`.
nonisolated struct DirectoryDigest: Sendable, Equatable, Codable {
    struct Item: Sendable, Equatable, Codable {
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

    struct SmallFiles: Sendable, Equatable, Codable {
        var count = 0
        var size: Int64 = 0
        var logicalSize: Int64 = 0
        var newest = ScanNode.unknownDate
        /// The files among them per category, as File Types counts them: symbolic links and devices have none. The tree
        /// keeps them with the aggregate (`SmallFileKinds`).
        var categories = CategoryTotals()
        /// How many of the files are further links of a file counted elsewhere, with no size.
        var duplicateLinks = 0
        /// How many of the files are only in the cloud, and their content size, which takes no space on this Mac: a further
        /// link of one adds no content, as it adds no size. The tree keeps them with the aggregate too.
        var cloudOnlyFiles = 0
        var cloudOnlyBytes: Int64 = 0

        /// Adds a symbolic link or a device, which has no category.
        mutating func add(_ entry: DirectoryEntry, size: Int64, logicalSize: Int64) {
            add(size: size, logicalSize: logicalSize, modified: ScanNode.encode(secondsSince1970: entry.modified))
        }

        /// Adds a file of `category`.
        mutating func add(_ entry: DirectoryEntry, category: FileCategory) {
            add(entry, size: entry.allocatedSize, logicalSize: entry.logicalSize)
            categories.add(category, bytes: entry.allocatedSize)
            if entry.isDataless {
                addCloudOnly(content: entry.logicalSize)
            }
        }

        /// Adds a link of a file with several, as `count(_:isFirstLink:)` counted it: a further link has no size.
        mutating func add(_ link: Item) {
            add(size: link.size, logicalSize: link.logicalSize, modified: link.modified)
            categories.add(link.category, bytes: link.size)
            if link.flags.contains(.duplicateLink) {
                duplicateLinks += 1
            }
            if link.flags.contains(.cloudOnly) {
                addCloudOnly(content: link.logicalSize)
            }
        }

        private mutating func addCloudOnly(content: Int64) {
            cloudOnlyFiles += 1
            cloudOnlyBytes += content
        }

        private mutating func add(size: Int64, logicalSize: Int64, modified: Int32) {
            count += 1
            self.size += size
            self.logicalSize += logicalSize
            newest = max(newest, modified)
        }
    }

    /// A file with several hard links, not counted yet: `item` is what it is as the link that carries the file's size.
    struct Link: Sendable, Equatable, Codable {
        var file: HardLinkRegistry.Identity
        var item: Item
        /// Whether it is kept one by one as that link; any further link is among the smaller files.
        var isKept: Bool
    }

    var items: [Item] = []
    var small = SmallFiles()
    /// The files with several hard links, until `count(_:isFirstLink:)` counts each into `items` or `small`.
    var links: [Link] = []
    /// Entries the file system reported an error for, which are left out. The tree keeps them with the folder.
    var entryErrors = 0

    /// Files and bytes per category over the files it counted: those kept one by one and the smaller ones. The tree sums
    /// them the same way, from its files and the kinds of its aggregates.
    var categoryTotals: CategoryTotals {
        var totals = small.categories
        for item in items where item.kind == .file {
            totals.add(item.category, bytes: item.size)
        }
        return totals
    }

    /// Further links to files counted elsewhere, all among the smaller files.
    var duplicateLinks: Int {
        small.duplicateLinks
    }

    /// Files only in the cloud among those it counted, those kept one by one and the smaller ones. The tree sums them the
    /// same way, from its files and its aggregates' records.
    var cloudOnlyFiles: Int {
        small.cloudOnlyFiles + items.count { $0.kind == .file && $0.flags.contains(.cloudOnly) }
    }

    /// The content size of `cloudOnlyFiles`, which takes no space on this Mac.
    var cloudOnlyBytes: Int64 {
        items.reduce(small.cloudOnlyBytes) { $0 + ($1.kind == .file && $1.flags.contains(.cloudOnly) ? $1.logicalSize : 0) }
    }

    /// Folds `entries`, the contents of the directory at `parentPath`, into what the scan keeps.
    static func make(
        entries: [DirectoryEntry],
        parentPath: String,
        inheritedCategory: FileCategory?,
        options: ScanOptions,
        categories: inout FileCategoryCache,
        canCrossInto: (String) -> Bool = { _ in false },
        macOS: MacOSVolumes? = nil
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
                if let macOS, !macOS.keeps(entry, at: path) {
                    continue
                }
                digest.items.append(folder(
                    entry,
                    path: path,
                    inherited: inheritedCategory,
                    options: options,
                    categories: &categories,
                    entersMount: macOS?.helperMounts.contains(path) ?? false,
                    canCrossInto: canCrossInto
                ))
            case .file:
                digest.addFile(entry, inherited: inheritedCategory, options: options, categories: &categories)
            case .symlink, .special:
                digest.small.add(entry, size: entry.allocatedSize, logicalSize: entry.logicalSize)
            }
        }
        if macOS != nil {
            for index in digest.items.indices {
                digest.items[index].flags.insert(.macOSVolume)
            }
            for index in digest.links.indices {
                digest.links[index].item.flags.insert(.macOSVolume)
            }
        }
        return digest
    }

    /// Counts `link`, one of `links`, which the caller takes out of them. As the first link of its file the scan counts,
    /// it is counted in full, kept one by one or summed with the smaller files like any file, and the item kept is
    /// returned; as any other, it is summed with no size and flagged `duplicateLink`.
    mutating func count(_ link: Link, isFirstLink: Bool) -> Item? {
        var item = link.item
        if !isFirstLink {
            item.flags.insert(.duplicateLink)
            item.size = 0
            item.logicalSize = 0
        }
        guard isFirstLink, link.isKept else {
            small.add(item)
            return nil
        }
        items.append(item)
        return item
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
        entersMount: Bool,
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
            item.crossesVolume = entersMount || (options.crossesVolumes && canCrossInto(path))
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
        categories: inout FileCategoryCache
    ) {
        var flags: ScanNodeFlags = []
        if entry.isHidden {
            flags.insert(.hidden)
        }
        if entry.isDataless {
            flags.insert(.cloudOnly)
        }
        if entry.extendedFlags & DirectoryEntry.mayShareBlocks != 0 {
            flags.insert(.sharesBlocks)
        }
        if entry.extendedFlags & DirectoryEntry.isPurgeable != 0 {
            flags.insert(.purgeable)
        }
        let category = inherited ?? categories.category(of: entry.name)
        let threshold = options.smallFileThreshold
        let keeps = entry.allocatedSize >= threshold || (flags.contains(.cloudOnly) && entry.logicalSize >= threshold)
        if entry.linkCount > 1 {
            let file = HardLinkRegistry.Identity(device: entry.device, inode: entry.inode)
            links.append(Link(file: file, item: Self.file(entry, category: category, flags: flags.union(.hardLink)), isKept: keeps))
            return
        }
        guard keeps else {
            small.add(entry, category: category)
            return
        }
        items.append(Self.file(entry, category: category, flags: flags))
    }

    private static func file(_ entry: DirectoryEntry, category: FileCategory, flags: ScanNodeFlags) -> Item {
        var item = Item(
            name: entry.name,
            kind: .file,
            size: entry.allocatedSize,
            logicalSize: entry.logicalSize,
            category: category,
            flags: flags
        )
        item.created = ScanNode.encode(secondsSince1970: entry.created)
        item.modified = ScanNode.encode(secondsSince1970: entry.modified)
        item.accessed = ScanNode.encode(secondsSince1970: entry.accessed)
        return item
    }
}
