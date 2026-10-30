import Foundation
import OrielCore
import Synchronization
import Testing

struct SettingsSyncTests {
    private let past = Date(timeIntervalSince1970: 1_800_000_000)

    private func json(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func snapshot(_ device: String, _ entries: [String: SettingsSnapshot.Entry]) -> SettingsSnapshot {
        SettingsSnapshot(device: device, deviceName: device, written: past, entries: entries)
    }

    @Test(arguments: [
        "shortcuts.captureArea", "app.enabledModules", "clipboard.itemLimit", "capture.copiesToClipboard", "tiling.gap",
        "colorPicker.defaultFormat", "screenRuler.unit", "disk.exclusions", "activity.interval",
    ])
    func preferencesAndShortcutsSync(_ name: String) {
        #expect(SettingsSyncPolicy.syncs(name))
    }

    /// Folders and bookmarks, upload destinations (whose credentials stay in this Mac's keychain), one-time notices
    /// and the sync bookkeeping stay on this Mac.
    @Test(arguments: [
        "capture.saveFolder", "capture.saveLocation", "recording.outputDirectory", "upload.destinations", "app.onboardingCompleted",
        "app.lastBootstrapImport", "sync.deviceID", "clipboard.openedPasteboardSettings", "disk.lastScanDate", "NSWindow Frame Main",
        "disk.explainedFolderAccess", "disk.helperBuild", "recording.outputFolder",
    ])
    func thisMacsOwnSettingsStay(_ name: String) {
        #expect(!SettingsSyncPolicy.syncs(name))
    }

    @Test func theNewestChangeOnAnyMacWins() throws {
        let local = try snapshot("here", [
            "shortcuts.captureArea": .init(value: json("here"), modified: past.addingTimeInterval(10)),
            "clipboard.itemLimit": .init(value: json(500), modified: past.addingTimeInterval(50)),
        ])
        let laptop = try snapshot("laptop", [
            "shortcuts.captureArea": .init(value: json("laptop"), modified: past.addingTimeInterval(20)),
            "clipboard.itemLimit": .init(value: json(100), modified: past.addingTimeInterval(40)),
        ])
        let studio = try snapshot("studio", [
            "shortcuts.captureArea": .init(value: json("studio"), modified: past.addingTimeInterval(30)),
        ])
        let changes = SettingsMerge.changes(local: local, others: [laptop, studio])
        #expect(try changes["shortcuts.captureArea"]?.value == json("studio"))
        #expect(changes["clipboard.itemLimit"] == nil, "this Mac's change is newer")
        #expect(changes.count == 1)
    }

    /// A Mac that turns sync on has never changed its settings since sync began, so it adopts the other Macs'.
    @Test func aMacThatJustTurnedSyncOnAdoptsTheOthersSettings() throws {
        let local = try snapshot("new", ["switcher.showOn": .init(value: json("pointer"), modified: .distantPast)])
        let other = try snapshot("old", [
            "switcher.showOn": .init(value: json("main"), modified: past),
            "editor.defaultWidth": .init(value: json(3), modified: past),
        ])
        let changes = SettingsMerge.changes(local: local, others: [other])
        #expect(try changes["switcher.showOn"]?.value == json("main"))
        #expect(try changes["editor.defaultWidth"]?.value == json(3))
    }

    @Test func aResetTravelsButNothingChangesForEqualValuesTheOwnSnapshotOrLocalSettings() throws {
        let local = try snapshot("here", [
            "capture.format": .init(value: json("png"), modified: past),
            "editor.color": .init(value: json("red"), modified: past),
        ])
        let other = try snapshot("other", [
            "capture.format": .init(value: nil, modified: past.addingTimeInterval(5)),
            "editor.color": .init(value: json("red"), modified: past.addingTimeInterval(5)),
            "translation.unsetElsewhere": .init(value: nil, modified: past),
            "capture.saveFolder": .init(value: json("/Users/other/Desktop"), modified: past.addingTimeInterval(5)),
        ])
        let own = try snapshot("here", ["clipboard.itemLimit": .init(value: json(1), modified: past.addingTimeInterval(99))])
        let changes = SettingsMerge.changes(local: local, others: [other, own])
        #expect(changes.keys.sorted() == ["capture.format"])
        #expect(changes["capture.format"]?.value == nil)
    }

    @MainActor
    @Test func storedJSONRoundTripsAndSaysItCameFromSync() throws {
        let suite = "com.codertapsu.oriel.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        let key = SettingKey("clipboard.itemLimit", default: 500)
        settings[key] = 200
        let stored = try #require(settings.storedJSON(named: key.name))
        #expect(settings.storedNames(where: SettingsSyncPolicy.syncs).contains(key.name))

        let origins = OriginLog()
        let observer = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification,
            object: settings,
            queue: nil
        ) { note in
            origins.add(note.userInfo?["origin"] as? String)
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        settings.setStoredJSON(nil, named: key.name)
        #expect(settings[key] == 500)
        settings.setStoredJSON(stored, named: key.name)
        #expect(settings[key] == 200)
        settings[key] = 300
        #expect(origins.all == ["sync", "sync", nil])
    }
}

/// The origins of the change notifications, which an observer's `@Sendable` block adds to.
private final class OriginLog: Sendable {
    private let values = Mutex<[String?]>([])

    func add(_ origin: String?) {
        values.withLock { $0.append(origin) }
    }

    var all: [String?] {
        values.withLock { $0 }
    }
}
