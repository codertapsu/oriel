import AppKit

/// App icons and image thumbnails for the list, kept for the life of the panel. Thumbnails are bounded by `NSCache`.
final class ClipboardIconCache {
    private var appIcons: [String: NSImage] = [:]
    private let thumbnails = NSCache<NSUUID, NSImage>()

    init() {
        thumbnails.countLimit = 300
    }

    func appIcon(bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = appIcons[bundleID] {
            return icon
        }
        let icon: NSImage? = if bundleID == Bundle.main.bundleIdentifier {
            NSApp.applicationIconImage
        } else {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
        appIcons[bundleID] = icon
        return icon
    }

    func fileIcon(_ url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    func thumbnail(for id: UUID) -> NSImage? {
        thumbnails.object(forKey: id as NSUUID)
    }

    func setThumbnail(_ image: NSImage, for id: UUID) {
        thumbnails.setObject(image, forKey: id as NSUUID)
    }
}
