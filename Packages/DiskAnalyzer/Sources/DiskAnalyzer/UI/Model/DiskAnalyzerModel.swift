import AppKit
import Observation
import OrielCore

/// The Disk Space Analyzer window's state: the volumes and cloud locations, the open scan and where the user is in it,
/// the analyses, and the file operation running. Heavy work — scanning, layouts, queries, hashing, edits of a large
/// tree — runs off the main thread; this model only keeps the results. Edits of the tree run one after another
/// (`serially`), so a refresh after a change on disk and a file operation can never undo each other.
@MainActor
@Observable
final class DiskAnalyzerModel {
    /// What the main area shows.
    enum Content: Equatable {
        case welcome
        case scanning
        case scan
        case volume(VolumeInfo)
        case cloud(CloudLocation)
        case record(ScanRecord)
    }

    /// A problem or result to show the user in an alert.
    struct Message: Equatable {
        var title: String
        var text: String
    }

    var volumes: [VolumeInfo] = []
    var clouds: [CloudLocation] = []
    var records: [ScanRecord] = []
    /// The sidebar's selection.
    var source: DiskSource?

    var phase: ScanPhase = .idle
    var target: ScanTarget?
    var tree: ScanTree?
    var summary: ScanSummary?
    /// What changed since the previous scan of the same folder.
    var diff: SnapshotDiff?
    /// Bumped on every change of the tree, so views know to draw again without comparing trees.
    var treeVersion = 0

    /// The folder the views show.
    var focus: Int32 = ScanTree.rootIndex
    var selection: [Int32] = []
    var view: DiskView = .sunburst {
        didSet {
            if view != oldValue {
                settings[DiskSettings.view] = view.rawValue
            }
        }
    }

    var search = ""
    /// A category File Types asked Biggest Files to show; taken by the list when it shows.
    var categoryRequest: FileCategory?
    /// The notes above the views the user hid for this scan.
    var hiddenNotes = Set<String>()
    /// While Read as Administrator runs (`readAsAdministrator(through:)`).
    var isReadingAsAdministrator = false
    /// Oriel's helper for Read as Administrator, read when the window opens, when Oriel comes to the front, when Settings
    /// changes it and before every read through it.
    var helperStatus = PrivilegedReader.Status.unavailable

    /// Whether the open scan shows Full Disk Access in effect (`FullDiskAccessEvidence`); nil when it cannot tell.
    var hasFullDiskAccess: Bool? {
        tree.flatMap { FullDiskAccessEvidence.isGranted(in: $0, home: NSHomeDirectory()) }
    }

    var duplicates = DuplicateSearch.idle
    /// The copies marked for removal in Duplicates.
    var duplicateMarks: Set<Int32> = []
    var hogs: [String: HogMeasurement] = [:]
    /// Spotlight's "last opened" dates, for the files Old Files asked about.
    var lastOpened: [Int32: Date] = [:]
    var localSnapshots: [String: [LocalSnapshotList.Snapshot]] = [:]
    var operation: OperationState?

    /// A file operation running, for the progress sheet.
    struct OperationState: Equatable {
        var kind: FileOperation.Kind
        var progress: FileOperationProgress
    }

    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let store: ScanSnapshotStore
    @ObservationIgnored var undoManager: UndoManager?
    /// Shows alerts; set by the window.
    @ObservationIgnored var onMessage: ((Message) -> Void)?
    /// Opens Settings at Disk Space Analyzer; from the module.
    @ObservationIgnored var openSettings: (() -> Void)?
    @ObservationIgnored private(set) var firmlinks = FirmlinkMap.empty
    /// Preboot, VM, Update…: entered when macOS's own volumes are counted file by file.
    @ObservationIgnored private(set) var helperMounts = Set<String>()
    @ObservationIgnored var cancellation: CancellationFlag?
    @ObservationIgnored var operationCancellation: CancellationFlag?
    @ObservationIgnored var duplicateCancellation: CancellationFlag?
    @ObservationIgnored var scanTask: Task<Void, Never>?
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored let watcher = ScanWatcher()
    @ObservationIgnored private let volumeWatcher = VolumeWatcher()
    @ObservationIgnored var pendingFolders = Set<String>()
    @ObservationIgnored var pendingDeepFolders = Set<String>()
    @ObservationIgnored var refreshDelay: Task<Void, Never>?
    /// Files Spotlight was asked about, answered or not, so none is asked twice.
    @ObservationIgnored var askedLastOpened = Set<Int32>()
    /// Volumes whose local snapshots were asked for.
    @ObservationIgnored var localSnapshotLoads = Set<String>()
    /// Read the open scan's folders as soon as the user has allowed the helper in System Settings.
    @ObservationIgnored var readsAfterHelperApproval = false
    @ObservationIgnored private var activationObserver: (any NSObjectProtocol)?
    @ObservationIgnored let log = Log.logger("disk")

    init(settings: SettingsStore, store: ScanSnapshotStore = ScanSnapshotStore()) {
        self.settings = settings
        self.store = store
        view = DiskView(rawValue: settings[DiskSettings.view]) ?? .sunburst
        volumeWatcher.onChange = { [weak self] in self?.refreshSources() }
        watcher.onChange = { [weak self] in self?.filesChanged($0) }
    }

    // MARK: Window

    /// The window opened: follow the volumes and read where things are.
    func windowOpened() {
        volumeWatcher.start()
        refreshSources()
        refreshHelperStatus()
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshHelperStatus() }
        }
    }

    /// The window closed: stop everything, and let the scan go, so a closed window holds no memory and does no work.
    func windowClosed() {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = nil
        readsAfterHelperApproval = false
        volumeWatcher.stop()
        watcher.stop()
        refreshDelay?.cancel()
        cancellation?.cancel()
        duplicateCancellation?.cancel()
        scanTask = nil
        isReadingAsAdministrator = false
        tree = nil
        summary = nil
        target = nil
        diff = nil
        phase = .idle
        duplicates = .idle
        duplicateMarks = []
        lastOpened = [:]
        askedLastOpened = []
        hogs = [:]
        selection = []
        focus = ScanTree.rootIndex
        treeVersion += 1
    }

    var content: Content {
        if let target, phase != .idle, source == nil || source?.path == target.requestedPath {
            return phase.isScanning ? .scanning : .scan
        }
        switch source {
        case let .volume(path): return volumes.first { $0.path == path }.map(Content.volume) ?? .welcome
        case let .cloud(path): return clouds.first { $0.path == path }.map(Content.cloud) ?? .welcome
        case let .folder(path): return records.first { $0.rootPath == path }.map(Content.record) ?? .welcome
        case nil: return .welcome
        }
    }

    /// The remembered scans the sidebar lists: the newest of each folder that is not a volume or cloud location.
    var recentFolders: [ScanRecord] {
        let elsewhere = Set(volumes.map(\.path) + clouds.map(\.path))
        return ScanRecord.latestPerRoot(records.filter { !elsewhere.contains($0.rootPath) }, limit: 8)
    }

    /// Re-reads the volumes, the cloud locations and the remembered scans.
    func refreshSources() {
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                (
                    VolumeService.mountedVolumes(),
                    VolumeService.firmlinks(),
                    CloudLocator.locations(home: NSHomeDirectory()),
                    VolumeService.helperVolumeMounts()
                )
            }.value
            volumes = found.0
            firmlinks = found.1
            clouds = found.2
            helperMounts = found.3
            records = await store.records()
        }
    }

    func show(_ message: Message) {
        onMessage?(message)
    }

    // MARK: Edits, one at a time

    /// Runs `work` after every edit queued before it.
    func serially(_ work: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await work()
        }
    }

    /// Takes `tree` as the open scan's tree, keeping the folder and selection where they still exist.
    func adopt(_ updated: ScanTree) {
        let oldTree = tree
        if let oldTree, oldTree.generation != updated.generation {
            // Indices changed: find the same items again by path.
            let focusPath = oldTree.path(of: focus)
            let selected = selection.map(oldTree.path(of:))
            focus = updated.index(ofPath: focusPath) ?? ScanTree.rootIndex
            selection = selected.compactMap(updated.index(ofPath:))
            duplicateMarks = []
            duplicates = .idle
            lastOpened = [:]
            askedLastOpened = []
        }
        if !updated.contains(focus) {
            focus = oldTree.flatMap { old in old.lineage(of: focus).reversed().first(where: updated.contains) } ?? ScanTree.rootIndex
        }
        selection = selection.filter(updated.contains)
        duplicateMarks = duplicateMarks.filter(updated.contains)
        tree = updated
        treeVersion += 1
    }
}
