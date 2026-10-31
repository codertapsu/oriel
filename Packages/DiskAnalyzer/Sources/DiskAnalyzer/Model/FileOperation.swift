import Foundation

/// A file operation the user asked for and confirmed.
nonisolated struct FileOperation: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case copy(to: URL)
        case move(to: URL)
        /// Move to the Trash, with Undo.
        case trash
        /// Delete at once, without the Trash: asked for twice.
        case delete

        var verb: String {
            switch self {
            case .copy: "Copying"
            case .move: "Moving"
            case .trash: "Moving to the Trash"
            case .delete: "Deleting"
            }
        }

        var pastTense: String {
            switch self {
            case .copy: "copied"
            case .move: "moved"
            case .trash: "moved to the Trash"
            case .delete: "deleted"
            }
        }

        var isDestructive: Bool {
            self == .trash || self == .delete
        }

        /// Whether the items leave where they were: everything but a copy.
        var takesItemsAway: Bool {
            if case .copy = self {
                return false
            }
            return true
        }
    }

    var kind: Kind
    var items: [URL]
    /// Content bytes, from the scan, for the progress bar of a copy or move.
    var totalBytes: Int64
}

/// How far an operation has got.
nonisolated struct FileOperationProgress: Sendable, Equatable {
    var completedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var completedItems = 0
    var totalItems = 0
    var currentName = ""

    /// From 0 to 1: by bytes when they are known, else by items.
    var fraction: Double {
        if totalBytes > 0 {
            return min(1, Double(completedBytes) / Double(totalBytes))
        }
        return totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
    }
}

/// An item now in the Trash, and where it was, for Undo.
nonisolated struct TrashedItem: Sendable, Equatable {
    var original: URL
    var inTrash: URL
}

/// What an operation did, item by item.
nonisolated struct FileOperationReport: Sendable, Equatable {
    struct Failure: Sendable, Equatable {
        var url: URL
        var message: String
    }

    /// Items that were copied, moved, trashed or deleted.
    var completed: [URL] = []
    /// Where copies and moved items now are.
    var created: [URL] = []
    var trashed: [TrashedItem] = []
    var failures: [Failure] = []
    /// Items Oriel would not touch, with the reason.
    var refused: [Failure] = []
    var wasCancelled = false

    var hasProblems: Bool {
        !failures.isEmpty || !refused.isEmpty
    }
}
