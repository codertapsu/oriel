import Darwin
import Foundation

/// Gathers the facts Clean Up decides from (PLAN §7.10 item 19), off the main thread. From the scan: the folder's size,
/// dates, contents, kinds of files, repositories and the caches inside. From the folder itself: its names (with the small
/// files the scan summed up), its CACHEDIR.TAG, its Time Machine exclusion, whether the user may remove it, and the
/// processes using it. It reads names and attributes, and of the files only CACHEDIR.TAG's first line.
nonisolated enum CleanupInspector {
    /// What opens a valid `CACHEDIR.TAG` (the Cache Directory Tagging Specification).
    static let cacheTagSignature = "Signature: 8a477f597d28d172789f06886806bc55"

    /// `facts` (the path and what the window knows) filled in from the tree, the folder and its users.
    static func gather(_ facts: CleanupFacts, node: Int32, in tree: ScanTree) -> CleanupFacts {
        var facts = facts
        addTreeFacts(&facts, node: node, tree: tree)
        addFolderFacts(&facts)
        facts.users = users(of: facts.path)
        return facts
    }

    /// One walk of the folder's part of the tree: its contents with when each was last used, the kinds of files, the
    /// repositories and the outermost caches inside.
    static func addTreeFacts(_ facts: inout CleanupFacts, node: Int32, tree: ScanTree) {
        let item = tree[node]
        facts.bytes = item.size
        facts.fileCount = Int(item.fileCount)
        facts.folderCount = Int(item.folderCount)
        let children = tree.childrenBySize(of: node).filter { !tree[$0].kind.isSynthetic }
        var used = [Int32?](repeating: nil, count: children.count)
        var categories: [FileCategory: Int64] = [:]
        var repositories = 0
        var caches: [CleanupFacts.Child] = []
        let git = tree.names.firstIndex(of: ".git").map(Int32.init)
        // Every node below the folder, with the child it is under and whether it is inside a cache already.
        var stack = tree.children(of: node).map { (node: $0, child: children.firstIndex(of: $0), inCache: false) }
        while let next = stack.popLast() {
            let (current, child, inCache) = next
            let entry = tree[current]
            let latest = max(entry.modified, entry.accessed)
            if let child, latest != ScanNode.unknownDate {
                used[child] = max(used[child] ?? latest, latest)
            }
            if entry.kind == .file || entry.kind == .smallFiles {
                categories[entry.category, default: 0] += entry.size
            }
            var isCache = inCache
            if entry.kind.isContainer {
                if git != nil, entry.name == git {
                    repositories += 1
                }
                if !inCache, CleanupAdvisor.cacheNames.contains(tree.name(of: current)) {
                    caches.append(CleanupFacts.Child(
                        name: tree.name(of: current), path: facts.path + "/" + relativePath(of: current, below: node, in: tree),
                        bytes: entry.size, isFolder: true, lastUsed: ScanNode.decode(latest)
                    ))
                    isCache = true
                }
            }
            for grandchild in tree.children(of: current) {
                stack.append((grandchild, child, isCache))
            }
        }
        facts.children = children.enumerated().map { index, child in
            let name = tree.name(of: child)
            let own = max(tree[child].modified, tree[child].accessed)
            let latest = max(used[index] ?? own, own)
            return CleanupFacts.Child(
                name: name, path: facts.path + "/" + name, bytes: tree[child].size, isFolder: tree[child].kind.isContainer,
                lastUsed: ScanNode.decode(latest)
            )
        }
        facts.lastUsed = facts.children.compactMap(\.lastUsed).max()
        facts.categories = categories
        facts.repositories = repositories
        facts.cacheFolders = caches.sorted { $0.bytes > $1.bytes }
    }

    /// `index`'s path from `ancestor`, one of its ancestors.
    static func relativePath(of index: Int32, below ancestor: Int32, in tree: ScanTree) -> String {
        tree.lineage(of: index).drop { $0 != ancestor }.dropFirst().map(tree.name(of:)).joined(separator: "/")
    }

    /// The names in the folder and next to it, its tags and whether the user may remove it.
    static func addFolderFacts(_ facts: inout CleanupFacts) {
        let manager = FileManager.default
        let parent = (facts.path as NSString).deletingLastPathComponent
        facts.names = Set((try? manager.contentsOfDirectory(atPath: facts.path)) ?? [])
        facts.siblingNames = Set((try? manager.contentsOfDirectory(atPath: parent)) ?? [])
        facts.isTaggedCache = facts.names.contains("CACHEDIR.TAG") && isCacheTag(facts.path + "/CACHEDIR.TAG")
        let values = try? URL(fileURLWithPath: facts.path).resourceValues(forKeys: [.isExcludedFromBackupKey])
        facts.isExcludedFromBackup = values?.isExcludedFromBackup ?? false
        // Moving the folder takes write access to its parent; moving what it holds, to the folder.
        facts.isRemovable = access(facts.path, W_OK) == 0 && access(parent, W_OK) == 0
    }

    static func isCacheTag(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: cacheTagSignature.utf8.count)) ?? Data()
        return String(bytes: data, encoding: .utf8) == cacheTagSignature
    }

    /// The processes using the folder, Oriel left out, named as Activity Monitor names them.
    static func users(of path: String) -> [CleanupFacts.User] {
        FolderUsers.uses(of: path, excluding: [getpid()]).map { use in
            let app = ProcessName.app(of: use.pid)
            let items = Set(use.paths.compactMap { inside -> String? in
                let rest = inside.dropFirst(path.count + 1)
                return rest.isEmpty ? nil : rest.split(separator: "/").first.map(String.init)
            })
            return CleanupFacts.User(
                pid: use.pid, name: app?.name ?? ProcessName.name(of: use.pid), bundleID: app?.bundleID, items: items, paths: use.paths
            )
        }
    }
}
