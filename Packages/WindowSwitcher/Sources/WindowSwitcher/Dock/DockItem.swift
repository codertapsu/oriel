import ApplicationServices
import CoreGraphics
import Foundation

/// One icon in the Dock as Accessibility describes it (PLAN §7.1.12): the Dock's `AXList` holds an `AXDockItem` per icon,
/// with its title, the URL of the app or folder, its frame and, for an app, whether it runs.
nonisolated struct DockItem: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        /// An app, running or kept in the Dock.
        case application
        /// A folder, file, minimized window, separator or the Trash.
        case other
    }

    var kind: Kind
    var title: String
    /// The app's bundle (or the folder or file); nil for the Trash and separators.
    var url: URL?
    /// Global CoreGraphics coordinates (points, top-left origin), as Accessibility reports them.
    var frame: CGRect
    var isRunning: Bool

    /// The same icon read again: the same app or folder in the same place, whatever changed in its state.
    func isSameIcon(as other: DockItem) -> Bool {
        url == other.url && title == other.title && frame.intersects(other.frame)
    }

    /// An item from its attribute values; nil without a frame, which the Dock gives every icon it shows.
    static func make(subrole: String?, title: String?, url: URL?, position: CGPoint?, size: CGSize?, isRunning: Bool?) -> DockItem? {
        guard let position, let size, size.width > 0, size.height > 0 else { return nil }
        return DockItem(
            kind: subrole == kAXApplicationDockItemSubrole ? .application : .other,
            title: title ?? "",
            url: url,
            frame: CGRect(origin: position, size: size),
            isRunning: isRunning ?? false
        )
    }
}
