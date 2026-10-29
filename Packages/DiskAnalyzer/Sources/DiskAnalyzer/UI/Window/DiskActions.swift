import AppKit

/// What the views ask of the window: menus, confirmations and panels, which belong to the window, not to a view.
protocol DiskActions: AnyObject {
    /// The context menu for `nodes`; for the folder shown when empty.
    func menu(for nodes: [Int32]) -> NSMenu
    func quickLook()
    func trash(_ nodes: [Int32])
    func deleteImmediately(_ nodes: [Int32])
    func copyTo(_ nodes: [Int32])
    func moveTo(_ nodes: [Int32])
    /// Confirms, then moves to the Trash paths that are not nodes of the scan, such as a space hog's contents.
    func trash(paths: [String], bytes: Int64, title: String)
    func scan(_ path: String)
    func chooseFolder()
    func eject(_ volume: VolumeInfo)
    func thinSnapshots(of volume: VolumeInfo)
    func deleteUnavailableSimulators()
    func showChanges()
    func exportCSV()
}
