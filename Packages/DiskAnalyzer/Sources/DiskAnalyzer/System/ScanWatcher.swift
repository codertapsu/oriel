import CoreServices
import Foundation

/// Watches the scanned folder with an FSEvents stream while the window is open, so the open scan follows what changes
/// on disk. The system batches events (`latency`); nothing here wakes up on its own. Oriel's own changes are left out
/// (`IgnoreSelf`): the window updates the scan itself after a file operation.
final class ScanWatcher {
    struct Change: Sendable, Equatable {
        /// Folders whose contents changed.
        var folders: [String]
        /// Folders that must be read again all the way down: the system dropped events, or said so.
        var deepFolders: [String]
        /// The watched folder itself was moved or deleted.
        var rootChanged: Bool
    }

    var onChange: ((Change) -> Void)?
    private var stream: FSEventStreamRef?
    private var relay: Relay?

    /// Hands events from the stream's callback, on the main queue, to the watcher.
    private final class Relay {
        weak var watcher: ScanWatcher?
    }

    func start(path: String, latency: TimeInterval = 1.5) {
        stop()
        let relay = Relay()
        relay.watcher = self
        self.relay = relay
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(relay).toOpaque(), retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let relay = Unmanaged<Relay>.fromOpaque(info).takeUnretainedValue()
            let paths = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
            let flags = Array(UnsafeBufferPointer(start: flags, count: count))
            MainActor.assumeIsolated { relay.watcher?.received(paths, flags) }
        }
        let options = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot
            | kFSEventStreamCreateFlagIgnoreSelf)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context, [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, options
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        relay = nil
    }

    private func received(_ paths: [String], _ flags: [FSEventStreamEventFlags]) {
        var change = Change(folders: [], deepFolders: [], rootChanged: false)
        let deep = FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
            | kFSEventStreamEventFlagKernelDropped)
        for (path, flag) in zip(paths, flags) {
            if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 {
                change.rootChanged = true
            } else if flag & deep != 0 {
                change.deepFolders.append(path)
            } else {
                change.folders.append(path)
            }
        }
        onChange?(change)
    }
}
