import AppKit
import Observation
import OrielCore
import os
import SystemConfiguration

/// Keeps the settings that sync (`SettingsSyncPolicy`) the same on every Mac of the user (PLAN §7.16). A change here
/// goes to iCloud two seconds after the last one; newer values from other Macs replace this Mac's. It uses iCloud
/// key-value storage when the app carries that entitlement and a folder in iCloud Drive otherwise.
///
/// Nothing polls: it reacts to setting changes, to iCloud's change notifications, to the app becoming active and to
/// wake. While the setting is off it observes nothing.
@MainActor
@Observable
final class SettingsSyncService {
    enum Status: Equatable {
        case off
        case unavailable
        case syncing
        case synced(Date, otherMacs: Int)
        case failed(String)
    }

    private(set) var status: Status = .off
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var backend: (any SettingsSyncBackend)?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    @ObservationIgnored private var isPulling = false
    @ObservationIgnored private var pullsAgain = false
    @ObservationIgnored private let log = Log.logger("sync")
    @ObservationIgnored private let uploadDelay: Duration
    @ObservationIgnored private let makeBackend: @MainActor () -> (any SettingsSyncBackend)?

    /// - Parameters:
    ///   - uploadDelay: how long after the last change this Mac's settings go out.
    ///   - makeBackend: the store to sync through; iCloud key-value storage when the app has the entitlement,
    ///     iCloud Drive otherwise, nil when neither can be used. Tests pass their own.
    init(
        settings: SettingsStore,
        uploadDelay: Duration = .seconds(2),
        makeBackend: @escaping @MainActor () -> (any SettingsSyncBackend)? = SettingsSyncService.iCloudBackend
    ) {
        self.settings = settings
        self.uploadDelay = uploadDelay
        self.makeBackend = makeBackend
    }

    /// iCloud key-value storage when the entitlement is there; else, in the Developer ID edition, a folder in iCloud
    /// Drive, which the App Store edition's sandbox does not reach (PLAN §19).
    static func iCloudBackend() -> (any SettingsSyncBackend)? {
        if KeyValueStoreSyncBackend.isAvailable {
            return KeyValueStoreSyncBackend()
        }
        #if APP_STORE
            return nil
        #else
            return ICloudDriveSyncBackend.isAvailable ? ICloudDriveSyncBackend() : nil
        #endif
    }

    /// How it would sync on this Mac, or nil while neither iCloud store can be used.
    var method: String? {
        if KeyValueStoreSyncBackend.isAvailable {
            return "iCloud key-value storage"
        }
        #if APP_STORE
            return nil
        #else
            return ICloudDriveSyncBackend.isAvailable ? "iCloud Drive" : nil
        #endif
    }

    /// Starts or stops with the setting; called at launch and whenever the setting changes.
    func update() {
        if settings[AppSettings.syncSettings] {
            start()
        } else {
            stop()
        }
    }

    /// Reads the other Macs' settings, then sends this Mac's.
    func syncNow() {
        pull(publishing: true)
    }

    func stop() {
        for (center, observer) in observers {
            center.removeObserver(observer)
        }
        observers = []
        uploadTask?.cancel()
        uploadTask = nil
        backend?.stop()
        backend = nil
        status = .off
    }

    private func start() {
        guard backend == nil else { return }
        guard let candidate = makeBackend() else {
            status = .unavailable
            return
        }
        do {
            try candidate.start()
        } catch {
            status = .failed(error.localizedDescription)
            return
        }
        candidate.onRemoteChange = { [weak self] in self?.pull() }
        backend = candidate
        observe()
        syncNow()
    }

    private func observe() {
        let center = NotificationCenter.default
        let changes = center.addObserver(forName: SettingsStore.didChangeNotification, object: settings, queue: .main) { [weak self] note in
            let name = note.userInfo?["key"] as? String ?? ""
            let fromSync = note.userInfo?["origin"] as? String == "sync"
            MainActor.assumeIsolated { self?.settingChanged(name, fromSync: fromSync) }
        }
        let active = center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let wake = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }
        observers = [(center, changes), (center, active), (workspace, wake)]
    }

    /// Notes when a synced setting changed here, so the newest change wins everywhere, and sends it soon.
    private func settingChanged(_ name: String, fromSync: Bool) {
        guard !fromSync else { return }
        var modified = settings[AppSettings.syncModified]
        let now = Date()
        if name.hasSuffix(".") {
            // `removeAll(withPrefix:)` reports the prefix: every synced setting under it was reset.
            let reset = modified.keys.filter { $0.hasPrefix(name) }
            guard !reset.isEmpty else { return }
            for key in reset {
                modified[key] = now
            }
        } else if SettingsSyncPolicy.syncs(name) {
            modified[name] = now
        } else {
            return
        }
        settings[AppSettings.syncModified] = modified
        scheduleUpload()
    }

    /// One upload `uploadDelay` after the last change; each change restarts the wait.
    private func scheduleUpload() {
        uploadTask?.cancel()
        let delay = uploadDelay
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.upload()
        }
    }

    private func upload() async {
        guard let backend else { return }
        do {
            try await backend.publish(localSnapshot())
        } catch {
            status = .failed(error.localizedDescription)
            log.error("settings were not sent: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func pull(publishing: Bool = false) {
        guard let backend else { return }
        guard !isPulling else {
            pullsAgain = true
            return
        }
        isPulling = true
        status = .syncing
        Task {
            do {
                let others = try await backend.others(excluding: deviceID)
                seedIfFirst(others: others)
                let changes = SettingsMerge.changes(local: localSnapshot(), others: others)
                apply(changes)
                if publishing || !changes.isEmpty {
                    try await backend.publish(localSnapshot())
                }
                status = .synced(Date(), otherMacs: others.count)
                if !changes.isEmpty {
                    log.notice("applied \(changes.count) settings from other Macs")
                }
            } catch {
                status = .failed(error.localizedDescription)
                log.error("settings sync failed: \(error.localizedDescription, privacy: .public)")
            }
            isPulling = false
            if pullsAgain {
                pullsAgain = false
                pull()
            }
        }
    }

    /// The first Mac to turn sync on brings its settings: they count as changed now. A Mac that finds others already
    /// syncing adopts theirs instead, because its own count as never changed.
    private func seedIfFirst(others: [SettingsSnapshot]) {
        guard !settings[AppSettings.syncSeeded] else { return }
        if others.isEmpty {
            var modified = settings[AppSettings.syncModified]
            let now = Date()
            for name in settings.storedNames(where: SettingsSyncPolicy.syncs) where modified[name] == nil {
                modified[name] = now
            }
            settings[AppSettings.syncModified] = modified
        }
        settings[AppSettings.syncSeeded] = true
    }

    private func apply(_ changes: [String: SettingsSnapshot.Entry]) {
        guard !changes.isEmpty else { return }
        var modified = settings[AppSettings.syncModified]
        for (name, entry) in changes.sorted(by: { $0.key < $1.key }) {
            settings.setStoredJSON(entry.value, named: name)
            modified[name] = entry.modified
        }
        settings[AppSettings.syncModified] = modified
    }

    private func localSnapshot() -> SettingsSnapshot {
        let modified = settings[AppSettings.syncModified]
        let names = Set(settings.storedNames(where: SettingsSyncPolicy.syncs)).union(modified.keys.filter(SettingsSyncPolicy.syncs))
        var entries: [String: SettingsSnapshot.Entry] = [:]
        for name in names {
            entries[name] = SettingsSnapshot.Entry(value: settings.storedJSON(named: name), modified: modified[name] ?? .distantPast)
        }
        return SettingsSnapshot(device: deviceID, deviceName: Self.computerName, written: Date(), entries: entries)
    }

    /// A random identifier for this Mac, made the first time sync runs and kept here.
    private var deviceID: String {
        if let id = settings[AppSettings.syncDeviceID] {
            return id
        }
        let id = UUID().uuidString
        settings[AppSettings.syncDeviceID] = id
        return id
    }

    private static var computerName: String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "Mac"
    }
}
