import Foundation

/// What a file list asks of the tree, worked out off the main thread: Biggest Files, Old Files or the search.
nonisolated struct FileQuery: Sendable, Equatable {
    enum Mode: Sendable, Equatable {
        case biggest, old, search
    }

    static let rowLimit = 1000

    var mode: Mode
    var version: Int
    var folder: Int32
    var filter: FileFilter
    var sort: FileSort
    var search: String
    var lastOpenedCount: Int

    struct Result: Sendable {
        var rows: [Int32]
        /// How many matched before the list was cut to `rowLimit`.
        var matches: Int
        var bytes: Int64
    }

    func run(in tree: ScanTree, lastOpened: [Int32: Date]) -> Result {
        let candidates: [Int32] = switch mode {
        case .biggest, .old: tree.files(under: folder)
        case .search: tree.search(search, under: folder)
        }
        let matching = candidates.filter { node in
            mode == .search ? filter.accepts(tree[node], name: tree.name(of: node))
                : filter.accepts(tree[node], name: tree.name(of: node), lastOpened: lastOpened[node])
        }
        // A folder that matches already holds the matches inside it: count those once.
        let matched = Set(matching)
        let outermost = mode == .search
            ? matching.filter { node in !tree.lineage(of: node).dropLast().contains(where: matched.contains) }
            : matching
        let bytes = outermost.reduce(Int64(0)) { $0 + tree[$1].size }
        // Sort the largest few thousand only: a list of every file of a disk helps nobody.
        let pool = sort.key == .size && !sort.ascending ? largest(matching, in: tree) : matching
        let rows = Array(sort.sorted(pool, in: tree, lastOpened: lastOpened).prefix(Self.rowLimit))
        return Result(rows: rows, matches: matching.count, bytes: bytes)
    }

    private func largest(_ nodes: [Int32], in tree: ScanTree) -> [Int32] {
        guard nodes.count > Self.rowLimit * 2 else { return nodes }
        return Array(nodes.sorted { tree[$0].size > tree[$1].size }.prefix(Self.rowLimit))
    }
}
