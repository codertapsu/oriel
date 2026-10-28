import CoreGraphics
import Foundation

/// The window server's list of every window on every Space (PLAN §7.1.1 item 2).
nonisolated enum ServerWindowList {
    /// `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)`, front to back.
    static func current() -> [ServerWindowRecord] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return parse(list)
    }

    /// Parses the dictionaries `CGWindowListCopyWindowInfo` returns; entries without an id or owner are
    /// skipped. The keys are the values of the `kCGWindow…` constants.
    static func parse(_ list: [[String: Any]]) -> [ServerWindowRecord] {
        list.compactMap { info in
            guard let id = (info["kCGWindowNumber"] as? NSNumber)?.uint32Value,
                  let pid = (info["kCGWindowOwnerPID"] as? NSNumber)?.int32Value
            else { return nil }
            let bounds = (info["kCGWindowBounds"] as? [String: Any]).flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) }
            return ServerWindowRecord(
                id: id,
                pid: pid,
                layer: (info["kCGWindowLayer"] as? NSNumber)?.intValue ?? 0,
                frame: bounds ?? .zero,
                alpha: (info["kCGWindowAlpha"] as? NSNumber)?.doubleValue ?? 1,
                isOnScreen: (info["kCGWindowIsOnscreen"] as? NSNumber)?.boolValue ?? false,
                title: info["kCGWindowName"] as? String
            )
        }
    }
}
