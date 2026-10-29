import AppKit

/// A row object for the outline view. Rows are kept by key and updated in place, so across updates AppKit sees the same
/// objects and keeps the selection and the expanded rows.
final class ProcessNode: NSObject {
    let key: ListNode.Key
    var metrics: ProcessMetrics
    var children: [ProcessNode] = []

    init(key: ListNode.Key, metrics: ProcessMetrics) {
        self.key = key
        self.metrics = metrics
    }

    var isGroup: Bool {
        if case .group = key {
            return true
        }
        return false
    }
}
