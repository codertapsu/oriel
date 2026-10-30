import AppKit
import UniformTypeIdentifiers

/// Icons for the lists: by file type and folder kind, from Launch Services without touching the file, so a list of
/// thousands of rows reads nothing from disk. Apps get their own icon, read once each and kept.
final class NodeIcons {
    private var byExtension: [String: NSImage] = [:]
    private var apps: [String: NSImage] = [:]
    private lazy var folder = NSWorkspace.shared.icon(for: .folder)
    private lazy var document = NSWorkspace.shared.icon(for: .data)

    func icon(for node: Int32, in tree: ScanTree, path: () -> String) -> NSImage {
        let item = tree[node]
        switch item.kind {
        case .folder:
            // The folder that holds macOS's own volumes.
            return tree.anchors[node] != nil && item.flags.contains(.macOSVolume) ? symbol("applelogo") : folder
        case .package:
            let name = tree.name(of: node)
            guard name.lowercased().hasSuffix(".app") else { return icon(forName: name, fallback: folder) }
            let path = path()
            if let known = apps[path] {
                return known
            }
            let image = NSWorkspace.shared.icon(forFile: path)
            if apps.count < 400 {
                apps[path] = image
            }
            return image
        case .file, .symlink, .special:
            return icon(forName: tree.name(of: node), fallback: document)
        case .smallFiles:
            return symbol("doc.on.doc")
        case .system:
            return symbol("applelogo")
        case .unaccounted:
            return symbol("questionmark.square.dashed")
        }
    }

    private func icon(forName name: String, fallback: NSImage) -> NSImage {
        guard let ext = FileCategory.fileExtension(of: name) else { return fallback }
        if let known = byExtension[ext] {
            return known
        }
        let image = UTType(filenameExtension: ext).map { NSWorkspace.shared.icon(for: $0) } ?? fallback
        byExtension[ext] = image
        return image
    }

    private func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? document
    }
}
