import Foundation
import OrielCore

/// Settings sync through iCloud Drive, in `Oriel/Settings/<device>.json`, which works with the app's current signing.
/// Each Mac writes only its own file, through `NSFileCoordinator`, so iCloud never has two versions of one file to
/// reconcile; a file presenter on the folder says when iCloud brings another Mac's file.
final class ICloudDriveSyncBackend: SettingsSyncBackend {
    /// The user's iCloud Drive; it exists while iCloud Drive is on.
    static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(
            path: "Library/Mobile Documents/com~apple~CloudDocs",
            directoryHint: .isDirectory
        )
    }

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: iCloudDrive.path)
    }

    let name = "iCloud Drive"
    var onRemoteChange: (() -> Void)?
    private let folder: URL
    private var presenter: FolderPresenter?

    init(folder: URL = ICloudDriveSyncBackend.iCloudDrive.appending(path: "Oriel/Settings", directoryHint: .isDirectory)) {
        self.folder = folder
    }

    func start() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let presenter = FolderPresenter(url: folder) { [weak self] in
            Task { @MainActor in self?.onRemoteChange?() }
        }
        NSFileCoordinator.addFilePresenter(presenter)
        self.presenter = presenter
    }

    func stop() {
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
        }
        presenter = nil
    }

    func publish(_ snapshot: SettingsSnapshot) async throws {
        let data = try JSONEncoder().encode(snapshot)
        let file = folder.appending(path: "\(snapshot.device).json")
        try await Task.detached { try Self.write(data, to: file) }.value
    }

    func others(excluding device: String) async throws -> [SettingsSnapshot] {
        let folder = folder
        return try await Task.detached {
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" && $0.deletingPathExtension().lastPathComponent != device }
                .compactMap { file in (try? Self.read(file)).flatMap { try? JSONDecoder().decode(SettingsSnapshot.self, from: $0) } }
        }.value
    }

    private nonisolated static func write(_ data: Data, to url: URL) throws {
        var coordination: NSError?
        var failure: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordination) { target in
            do {
                try data.write(to: target, options: .atomic)
            } catch {
                failure = error
            }
        }
        if let error = coordination ?? failure {
            throw error
        }
    }

    /// A coordinated read, which also asks iCloud for a file that is not downloaded yet.
    private nonisolated static func read(_ url: URL) throws -> Data {
        var coordination: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordination) { source in
            result = Result { try Data(contentsOf: source) }
        }
        if let coordination {
            throw coordination
        }
        return try result.get()
    }
}

/// Tells the backend when anything in its folder changes. File presenters are called on their own queue.
private final nonisolated class FolderPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let changed: @Sendable () -> Void

    init(url: URL, changed: @escaping @Sendable () -> Void) {
        presentedItemURL = url
        self.changed = changed
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
    }

    func presentedSubitemDidChange(at _: URL) {
        changed()
    }

    func presentedSubitemDidAppear(at _: URL) {
        changed()
    }

    func presentedItemDidChange() {
        changed()
    }
}
