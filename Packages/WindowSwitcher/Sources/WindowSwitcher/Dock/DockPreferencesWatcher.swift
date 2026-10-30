import Darwin
import Foundation

/// Says when the Dock's preferences change (PLAN §7.1.12): its size, edge, magnification, hiding, or the icons kept in it,
/// none of which Accessibility reports. A kqueue watch on the Preferences folder, where the preferences daemon replaces
/// `com.apple.dock.plist` when the Dock saves, and a look at that file's date whenever the folder changes. No timer.
final class DockPreferencesWatcher {
    private let folder: String
    private var source: (any DispatchSourceFileSystemObject)?
    private var lastModified: Date?

    init(folder: String = NSHomeDirectory() + "/Library/Preferences") {
        self.folder = folder
    }

    private var file: String {
        folder + "/\(DockAccessibility.bundleIdentifier).plist"
    }

    func start(onChange: @escaping @MainActor @Sendable () -> Void) {
        guard source == nil else { return }
        let descriptor = open(folder, O_EVTONLY)
        guard descriptor >= 0 else { return }
        lastModified = modified()
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let modified = self.modified()
                guard modified != self.lastModified else { return }
                self.lastModified = modified
                onChange()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func modified() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file))?[.modificationDate] as? Date
    }
}
