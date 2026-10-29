@testable import DiskAnalyzer
import Foundation
import Testing

/// The FSEvents stream on a folder the test creates: a change there is reported, with no polling.
@MainActor
struct ScanWatcherTests {
    @Test(.timeLimit(.minutes(1)))
    func aNewFileIsReported() async throws {
        let folder = try TemporaryFolder()
        let inner = try folder.folder("inner")
        let watcher = ScanWatcher()
        let changes = AsyncStream.makeStream(of: ScanWatcher.Change.self)
        watcher.onChange = { changes.continuation.yield($0) }
        watcher.start(path: folder.url.resolvingSymlinksInPath().path, latency: 0.05)
        defer { watcher.stop() }
        // The stream starts reporting from "now"; give it a moment to be in place before the change.
        try await Task.sleep(for: .milliseconds(300))
        // Made by another process: the stream leaves out Oriel's own changes, which the window applies itself.
        let made = await ProcessRunner.run("/usr/bin/touch", [inner.path + "/new.bin"])
        #expect(made.succeeded)
        var seen: [String] = []
        for await change in changes.stream {
            seen += change.folders + change.deepFolders
            if seen.contains(where: { $0.hasSuffix("/inner/") || $0.hasSuffix("/inner") }) {
                break
            }
        }
        #expect(seen.contains { ($0.hasSuffix("/") ? String($0.dropLast()) : $0).hasSuffix(inner.lastPathComponent) })
    }
}
