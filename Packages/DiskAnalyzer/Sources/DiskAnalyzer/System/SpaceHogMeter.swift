import Darwin
import Foundation

/// Measures one space hog: a quick scan of its folder that keeps no file one by one, a listing for files of a kind, or
/// a search of the open scan for folders with a name.
nonisolated enum SpaceHogMeter {
    static func measure(_ hog: SpaceHog, home: String, tree: ScanTree?) async -> HogMeasurement {
        switch hog.location {
        case .folder:
            guard let folder = hog.folder(home: home) else { return .none }
            return await measureFolder(folder, listsContents: hog.action == .trashContents)
        case let .files(_, extensions):
            guard let folder = hog.folder(home: home) else { return .none }
            return files(in: folder, extensions: extensions)
        case let .foldersNamed(name):
            guard let tree else { return .none }
            return folders(named: name, in: tree)
        }
    }

    private static func measureFolder(_ folder: String, listsContents: Bool) async -> HogMeasurement {
        var info = stat()
        guard lstat(folder, &info) == 0 else { return .none }
        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: folder)
        } catch {
            return .unreadable
        }
        var options = ScanOptions()
        // Every file is summed into its folder: only the total is wanted, so the scan stays tiny.
        options.smallFileThreshold = .max
        options.workerCount = 4
        let target = ScanTarget(requestedPath: folder, scanPath: folder, displayName: "", firmlinks: .empty)
        let outcome = await ScanEngine.scan(target, options: options, cancellation: CancellationFlag())
        let items = listsContents ? contents.filter { $0 != ".DS_Store" && $0 != ".localized" }.sorted()
            .map { folder + "/" + $0 } : [folder]
        guard outcome.tree.root.size > 0 || !items.isEmpty else { return .none }
        return .measured(bytes: outcome.tree.root.size, items: items)
    }

    private static func files(in folder: String, extensions: Set<String>) -> HogMeasurement {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: folder)
        } catch {
            return (error as NSError).code == NSFileReadNoSuchFileError ? .none : .unreadable
        }
        var bytes: Int64 = 0
        var items: [String] = []
        for name in names.sorted() where FileCategory.fileExtension(of: name).map(extensions.contains) == true {
            var info = stat()
            let path = folder + "/" + name
            guard lstat(path, &info) == 0 else { continue }
            bytes += Int64(info.st_blocks) * 512
            items.append(path)
        }
        return items.isEmpty ? .none : .measured(bytes: bytes, items: items)
    }

    /// The outermost folders called `name` in the scan: one inside another counts with the outer one.
    private static func folders(named name: String, in tree: ScanTree) -> HogMeasurement {
        guard let nameIndex = tree.names.firstIndex(of: name).map(Int32.init) else { return .none }
        let found = tree.descendants(of: ScanTree.rootIndex) { $0.kind.isContainer && $0.name == nameIndex }
        let set = Set(found)
        let outermost = found.filter { node in !tree.lineage(of: node).dropLast().contains(where: set.contains) }
        guard !outermost.isEmpty else { return .none }
        let sorted = outermost.sorted { tree[$0].size > tree[$1].size }
        return .measured(bytes: sorted.reduce(0) { $0 + tree[$1].size }, items: sorted.map(tree.displayPath(of:)))
    }
}
