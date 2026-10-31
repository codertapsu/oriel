import Darwin
import Foundation

/// Reads a folder tree with a few threads of its own. Reading a directory is a blocking system call, so the work runs
/// on plain threads rather than Swift's cooperative pool, which it would starve.
///
/// Folders to read sit on a stack (depth first, so it stays short); each thread takes one, reads it without a lock,
/// works out what to keep (`DirectoryDigest`), then takes the lock only to add the nodes, count the files with several
/// hard links against those the tree counted already, and push the subfolders. Progress is reported from inside that
/// step when enough time has passed since the last report: no timer. The last thread to finish sums the totals and
/// hands over the result.
final nonisolated class ScanEngine: @unchecked Sendable {
    /// One folder to read: added to (`merge`), or listed again after a change (`replace`).
    struct WorkItem: Sendable {
        enum Mode: Sendable {
            case merge
            case replace(keepsSubfolders: Bool)
        }

        var node: Int32
        var path: String
        var inherited: FileCategory?
        var mode: Mode = .merge
        /// On macOS's own volumes: their rules (`MacOSVolumes`).
        var macOS: MacOSVolumes?
    }

    struct Outcome: Sendable {
        var tree: ScanTree
        var summary: ScanSummary
    }

    private let condition = NSCondition()
    private let options: ScanOptions
    private let cancellation: CancellationFlag
    private let progress: @Sendable (ScanProgress) -> Void
    private let readerMode: DirectoryReader.Mode
    /// A scan from scratch sums every total; a refresh only those above the folders it read.
    private let isFullScan: Bool
    private let clock = ContinuousClock()
    private let started: ContinuousClock.Instant
    // Guarded by `condition`.
    private var tree: ScanTree
    private var summary = ScanSummary()
    private var stack: [WorkItem]
    private var active = 0
    private var finishedThreads = 0
    private var dirty = Set<Int32>()
    /// Whether the tree changed since a refresh last looked for files to count at another link.
    private var mayNeedRecounts = true
    private var current = ScanProgress()
    private var lastReport: ContinuousClock.Instant
    private var completion: (@Sendable (Outcome) -> Void)?

    private init(
        tree: ScanTree,
        work: [WorkItem],
        options: ScanOptions,
        cancellation: CancellationFlag,
        readerMode: DirectoryReader.Mode,
        isFullScan: Bool,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) {
        self.tree = tree
        stack = work
        self.isFullScan = isFullScan
        self.options = options
        self.cancellation = cancellation
        self.readerMode = readerMode
        self.progress = progress
        started = clock.now
        lastReport = started
    }

    // MARK: Entry points

    /// Reads `target` from scratch, with macOS's own volumes in a folder of their own when it names them.
    static func scan(
        _ target: ScanTarget,
        options: ScanOptions,
        cancellation: CancellationFlag,
        readerMode: DirectoryReader.Mode = .automatic,
        progress: @escaping @Sendable (ScanProgress) -> Void = { _ in }
    ) async -> Outcome {
        var tree = ScanTree(rootName: target.displayName, rootPath: target.scanPath, firmlinks: target.firmlinks)
        var info = stat()
        if stat(target.scanPath, &info) == 0 {
            tree.setRootDates(
                created: ScanNode.encode(secondsSince1970: Int64(info.st_birthtimespec.tv_sec)),
                modified: ScanNode.encode(secondsSince1970: Int64(info.st_mtimespec.tv_sec)),
                accessed: ScanNode.encode(secondsSince1970: Int64(info.st_atimespec.tv_sec))
            )
        }
        var work = [WorkItem(node: ScanTree.rootIndex, path: target.scanPath, inherited: nil)]
        if let macOS = target.macOSVolumes {
            let folder = DirectoryDigest.Item(name: macOS.displayName, kind: .folder, flags: .macOSVolume)
            let anchor = tree.appendAnchor(folder, path: macOS.systemPath)
            work.append(WorkItem(node: anchor, path: macOS.systemPath, inherited: nil, macOS: macOS))
            for mount in macOS.blockMounts.sorted() {
                let size = VolumeService.spaceUsed(mount) ?? 0
                tree.appendSynthetic(.system, name: (mount as NSString).lastPathComponent, size: size, to: anchor)
            }
        }
        return await run(
            tree: tree,
            work: work,
            options: options,
            cancellation: cancellation,
            readerMode: readerMode,
            isFullScan: true,
            progress: progress
        )
    }

    /// Reads `folders` of `tree` again after the file system reported changes there. Their subfolders keep what they
    /// held unless listed in `recursive`, which are read again all the way down. Folders read as an administrator stay
    /// as they were read, since the user's rights cannot read them again, and so do macOS's own volumes. A file with
    /// several hard links whose counted link went is then counted at another (`ScanTree.foldersToRecount()`).
    static func refresh(
        _ tree: ScanTree,
        folders: Set<Int32>,
        recursive: Set<Int32>,
        options: ScanOptions,
        cancellation: CancellationFlag
    ) async -> Outcome {
        let work = folders.union(recursive).filter { canReadAgain($0, in: tree) }.map { folder in
            rereading(folder, in: tree, keepsSubfolders: !recursive.contains(folder))
        }
        return await run(
            tree: tree,
            work: work,
            options: options,
            cancellation: cancellation,
            readerMode: .automatic,
            isFullScan: false,
            progress: { _ in }
        )
    }

    private static func run(
        tree: ScanTree,
        work: [WorkItem],
        options: ScanOptions,
        cancellation: CancellationFlag,
        readerMode: DirectoryReader.Mode,
        isFullScan: Bool,
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> Outcome {
        await withCheckedContinuation { continuation in
            let engine = ScanEngine(
                tree: tree,
                work: work,
                options: options,
                cancellation: cancellation,
                readerMode: readerMode,
                isFullScan: isFullScan,
                progress: progress
            )
            engine.start { continuation.resume(returning: $0) }
        }
    }

    /// Whether a refresh may list `folder` again: not what was read as an administrator, nor macOS's own volumes.
    private static func canReadAgain(_ folder: Int32, in tree: ScanTree) -> Bool {
        tree.contains(folder) && tree[folder].flags.isDisjoint(with: [.readAsAdministrator, .macOSVolume])
    }

    private static func rereading(_ folder: Int32, in tree: ScanTree, keepsSubfolders: Bool) -> WorkItem {
        WorkItem(
            node: folder,
            path: tree.path(of: folder),
            inherited: inheritedCategory(of: folder, in: tree),
            mode: .replace(keepsSubfolders: keepsSubfolders)
        )
    }

    /// The category files inside `folder` take: that of the package it is in, if any.
    private static func inheritedCategory(of folder: Int32, in tree: ScanTree) -> FileCategory? {
        tree.lineage(of: folder).first { tree[$0].kind == .package }.map { tree[$0].category }
    }

    // MARK: Threads

    private func start(completion: @escaping @Sendable (Outcome) -> Void) {
        self.completion = completion
        let threads = max(1, options.workerCount)
        for number in 0 ..< threads {
            let thread = Thread { [self] in work() }
            thread.name = "Oriel disk scan \(number + 1)"
            thread.qualityOfService = .userInitiated
            thread.start()
        }
    }

    private func work() {
        ScanIOPolicy.applyToCurrentThread()
        let reader = DirectoryReader(mode: readerMode)
        var categories = FileCategoryCache()
        condition.lock()
        while let item = nextItem() {
            condition.unlock()
            let read = reader.read(item.path)
            let digest = digest(of: read, item: item, categories: &categories)
            condition.lock()
            let report = merge(read, digest, item: item)
            active -= 1
            condition.broadcast()
            if let report {
                condition.unlock()
                progress(report)
                condition.lock()
            }
        }
        finishedThreads += 1
        let isLast = finishedThreads == max(1, options.workerCount)
        condition.broadcast()
        condition.unlock()
        if isLast {
            finish()
        }
    }

    /// The next folder to read, waiting while others are still being read; nil when the work is done or cancelled. When
    /// a refresh runs out of folders, the folders holding a further link of a file whose counted link it took out are
    /// read again, so that one counts it. Called with the lock held.
    private func nextItem() -> WorkItem? {
        while stack.isEmpty, active > 0, !cancellation.isCancelled {
            condition.wait()
        }
        if stack.isEmpty, mayNeedRecounts, !isFullScan, !cancellation.isCancelled {
            mayNeedRecounts = false
            stack = foldersToRecount()
        }
        guard !cancellation.isCancelled, let item = stack.popLast() else { return nil }
        active += 1
        return item
    }

    /// The folders to read again so that each file whose counted link went is counted at another (`ScanTree`'s
    /// `foldersToRecount()`). One a refresh may not read again, read as an administrator or macOS's own, is passed over,
    /// and the next folder holding a link of the same file is taken in its place. Called with the lock held.
    private func foldersToRecount() -> [WorkItem] {
        var folders = tree.foldersToRecount()
        while !folders.isEmpty {
            let readable = folders.filter { Self.canReadAgain($0, in: tree) }
            if !readable.isEmpty {
                return readable.map { Self.rereading($0, in: tree, keepsSubfolders: true) }
            }
            folders = tree.foldersToRecount()
        }
        return []
    }

    private func digest(of read: DirectoryReadResult, item: WorkItem, categories: inout FileCategoryCache) -> DirectoryDigest? {
        guard case let .listed(entries, _) = read else { return nil }
        return DirectoryDigest.make(
            entries: entries,
            parentPath: item.path,
            inheritedCategory: item.inherited,
            options: options,
            categories: &categories,
            canCrossInto: MountCheck.canCross,
            macOS: item.macOS
        )
    }

    /// Adds a read folder to the tree and queues its subfolders; returns progress to report, if it is time. Called
    /// with the lock held.
    private func merge(_ read: DirectoryReadResult, _ digest: DirectoryDigest?, item: WorkItem) -> ScanProgress? {
        switch read {
        case let .unreadable(error):
            if error != ENOENT {
                let reason = UnreadableReason(error: error)
                tree.setUnreadable(reason, at: item.node)
                summary.noteUnreadable(tree.firmlinks.visiblePath(for: item.path), reason: reason)
            }
        case let .listed(_, error):
            if error != 0 {
                tree.insertFlags(.partial, at: item.node)
            }
        }
        if var digest {
            let next: [(index: Int32, item: DirectoryDigest.Item)] = switch item.mode {
            case .merge: tree.merge(&digest, into: item.node)
            case let .replace(keepsSubfolders): tree.replaceContents(of: item.node, with: &digest, keepsSubfolders: keepsSubfolders)
            }
            summary.absorb(digest)
            dirty.insert(item.node)
            mayNeedRecounts = true
            for (index, child) in next {
                stack.append(WorkItem(
                    node: index,
                    path: DirectoryDigest.childPath(item.path, child.name),
                    inherited: child.inheritedCategory,
                    macOS: item.macOS
                ))
            }
            current.files += digest.items.count { $0.kind == .file } + digest.small.count
            current.bytes += digest.items.reduce(0) { $0 + $1.size } + digest.small.size
        }
        current.folders += 1
        current.unreadableFolders = summary.unreadableFolders
        let now = clock.now
        guard now - lastReport >= options.progressInterval else { return nil }
        lastReport = now
        current.currentPath = tree.firmlinks.visiblePath(for: item.path)
        current.elapsed = now - started
        return current
    }

    private func finish() {
        condition.lock()
        var tree = tree
        var summary = summary
        let dirty = dirty
        let completion = completion
        self.completion = nil
        condition.unlock()
        if isFullScan {
            tree.computeTotals()
        } else {
            tree.recomputeTotals(dirty: dirty)
        }
        tree.finishBuilding()
        summary.files = Int(tree.root.fileCount)
        summary.folders = Int(tree.root.folderCount)
        summary.bytes = tree.root.size
        summary.logicalBytes = tree.root.logicalSize
        summary.duration = clock.now - started
        summary.wasCancelled = cancellation.isCancelled
        completion?(Outcome(tree: tree, summary: summary))
    }
}
