/// What measuring one space hog found.
nonisolated enum HogMeasurement: Sendable, Equatable {
    case measuring
    /// `items` are what its action applies to: the folder's contents, the files or the folders found.
    case measured(bytes: Int64, items: [String])
    /// Nothing there on this Mac.
    case none
    /// macOS did not let Oriel read it: Full Disk Access, or the folder access the user refused.
    case unreadable

    var bytes: Int64 {
        if case let .measured(bytes, _) = self {
            return bytes
        }
        return 0
    }

    var items: [String] {
        if case let .measured(_, items) = self {
            return items
        }
        return []
    }
}
