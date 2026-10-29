import AppKit
import UniformTypeIdentifiers

/// Row icons: an app's own icon, a helper's from the innermost bundle around its executable, and the plain executable
/// icon for everything else. Loaded when a row first shows and kept by bundle, so an update costs nothing.
final class ProcessIconCache {
    static let size = NSSize(width: 16, height: 16)

    private var byBundle: [String: NSImage] = [:]
    private lazy var executable = sized(NSWorkspace.shared.icon(for: .unixExecutable))

    func icon(for process: ProcessMetrics, size: NSSize = ProcessIconCache.size) -> NSImage {
        let icon = bundleIcon(for: process) ?? executable
        guard size != Self.size else { return icon }
        let copy = icon.copy() as? NSImage ?? icon
        copy.size = size
        return copy
    }

    /// The `.app` (or `.appex`, `.xpc`) bundle an executable lives in, innermost first: what Finder would show.
    static func bundlePath(containing path: String) -> String? {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard let index = parts.lastIndex(where: { $0.hasSuffix(".app") || $0.hasSuffix(".appex") || $0.hasSuffix(".xpc") }) else {
            return nil
        }
        return parts[...index].joined(separator: "/")
    }

    private func bundleIcon(for process: ProcessMetrics) -> NSImage? {
        guard let bundle = process.app?.bundlePath ?? process.path.flatMap(Self.bundlePath(containing:)) else { return nil }
        if let icon = byBundle[bundle] {
            return icon
        }
        let icon = sized(NSWorkspace.shared.icon(forFile: bundle))
        byBundle[bundle] = icon
        return icon
    }

    private func sized(_ image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = Self.size
        return copy
    }
}
