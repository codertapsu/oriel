/// Files and bytes per `FileCategory`, exact over every file of a scan, the small ones included.
nonisolated struct CategoryTotals: Sendable, Equatable, Codable {
    private(set) var counts = [Int](repeating: 0, count: FileCategory.allCases.count)
    private(set) var bytes = [Int64](repeating: 0, count: FileCategory.allCases.count)

    mutating func add(_ category: FileCategory, bytes size: Int64, count: Int = 1) {
        counts[Int(category.rawValue)] += count
        bytes[Int(category.rawValue)] += size
    }

    mutating func merge(_ other: CategoryTotals) {
        for index in counts.indices {
            counts[index] += other.counts[index]
            bytes[index] += other.bytes[index]
        }
    }

    func count(of category: FileCategory) -> Int {
        counts[Int(category.rawValue)]
    }

    func bytes(of category: FileCategory) -> Int64 {
        bytes[Int(category.rawValue)]
    }

    var totalBytes: Int64 {
        bytes.reduce(0, +)
    }

    var totalCount: Int {
        counts.reduce(0, +)
    }

    /// The categories that have files, largest first.
    var ranked: [FileCategory] {
        FileCategory.allCases.filter { count(of: $0) > 0 }.sorted { bytes(of: $0) > bytes(of: $1) }
    }
}
