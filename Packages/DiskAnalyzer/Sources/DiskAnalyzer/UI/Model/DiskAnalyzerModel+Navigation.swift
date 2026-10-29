import AppKit
import SharedUI

/// Moving around the open scan, and the items the toolbar acts on.
extension DiskAnalyzerModel {
    /// From the root to the folder shown, for the breadcrumbs.
    var breadcrumbs: [Int32] {
        guard let tree, tree.contains(focus) else { return [] }
        return tree.lineage(of: focus)
    }

    /// Shows a folder's contents; a file is selected in its folder instead.
    func open(_ node: Int32) {
        guard let tree, tree.contains(node) else { return }
        if tree[node].kind.isContainer, tree[node].firstChild != ScanNode.none {
            focus = node
            selection = []
        } else if node != ScanTree.rootIndex {
            focus = tree[node].parent
            selection = [node]
        }
    }

    /// Goes to the folder above, with the one left selected.
    func goUp() {
        guard let tree, focus != ScanTree.rootIndex, tree.contains(focus) else { return }
        let previous = focus
        focus = tree[focus].parent
        selection = [previous]
    }

    var canGoUp: Bool {
        tree != nil && focus != ScanTree.rootIndex
    }

    /// The selected items that are real files and folders, without any that another selected folder already holds.
    var actionableSelection: [Int32] {
        guard let tree else { return [] }
        let real = selection.filter { tree.contains($0) && !tree[$0].kind.isSynthetic && $0 != ScanTree.rootIndex }
        let set = Set(real)
        return real.filter { node in !tree.lineage(of: node).dropLast().contains(where: set.contains) }
    }

    /// The path the user knows: the startup volume's root is `/`, not its data volume.
    func displayPath(of node: Int32) -> String {
        guard let tree else { return "" }
        if node == ScanTree.rootIndex, let target {
            return target.requestedPath
        }
        return tree.displayPath(of: node)
    }

    func url(of node: Int32) -> URL {
        let isFolder = tree.map { $0[node].kind.isContainer } ?? false
        return URL(fileURLWithPath: displayPath(of: node), isDirectory: isFolder)
    }

    /// The name shown for a node: an aggregate's count, a synthetic block's title.
    func displayName(of node: Int32) -> String {
        guard let tree, tree.contains(node) else { return "" }
        let item = tree[node]
        if item.kind == .smallFiles {
            return DiskFormat.smallFiles(Int(item.fileCount))
        }
        return tree.name(of: node)
    }

    func revealInFinder(_ nodes: [Int32]) {
        SystemLinks.reveal(nodes.map(url(of:)))
    }

    func openItems(_ nodes: [Int32]) {
        for node in nodes.prefix(20) {
            NSWorkspace.shared.open(url(of: node))
        }
    }

    func copyPaths(_ nodes: [Int32]) {
        let paths = nodes.map(displayPath(of:))
        guard !paths.isEmpty else { return }
        Pasteboard.copy(paths.joined(separator: "\n"))
    }

    /// Whether `node` is a downloaded iCloud Drive item, which Remove Download can make cloud-only again.
    func canRemoveDownload(_ node: Int32) -> Bool {
        guard let tree, tree.contains(node), !tree[node].kind.isSynthetic else { return false }
        let iCloud = NSHomeDirectory() + "/Library/Mobile Documents/"
        return displayPath(of: node).hasPrefix(iCloud) && !tree[node].flags.contains(.cloudOnly) && tree[node].size > 0
    }
}
