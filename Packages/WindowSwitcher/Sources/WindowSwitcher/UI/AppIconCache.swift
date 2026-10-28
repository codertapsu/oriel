import AppKit

/// App icons by pid, for tiles. Cleared when the module deactivates.
final class AppIconCache {
    private var icons: [Int32: NSImage] = [:]

    func icon(for pid: Int32, bundleID: String?) -> NSImage? {
        if let icon = icons[pid] {
            return icon
        }
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
            ?? bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        icons[pid] = icon
        return icon
    }

    func forget(pid: Int32) {
        icons[pid] = nil
    }

    /// Drops the icons of apps that have no window any more.
    func prune(keeping pids: Set<Int32>) {
        guard icons.keys.contains(where: { !pids.contains($0) }) else { return }
        icons = icons.filter { pids.contains($0.key) }
    }

    func removeAll() {
        icons.removeAll()
    }
}
