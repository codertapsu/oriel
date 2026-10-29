import AppKit

/// A view of the main area.
protocol DiskContentController: NSViewController {
    var actions: DiskActions? { get set }
    /// What Export as CSV writes: the rows shown, or everything below the folder shown.
    func exportableNodes() -> [Int32]
}

extension DiskContentController {
    func exportableNodes() -> [Int32] {
        []
    }
}
