import Foundation
@testable import Oriel
import OrielCore
import Testing

/// Two Macs syncing settings through one in-memory store (PLAN §7.16).
@MainActor
struct SettingsSyncServiceTests {
    private static let limit = SettingKey("clipboard.itemLimit", default: 500)
    private static let folder = SettingKey("capture.saveFolder", default: "~/Desktop")

    private func mac() throws -> (SettingsStore, String) {
        let suite = "com.codertapsu.oriel.tests.sync.\(UUID().uuidString)"
        return try (SettingsStore(defaults: #require(UserDefaults(suiteName: suite))), suite)
    }

    /// Waits for something the services do in their own tasks.
    private func until(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("timed out")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func theFirstMacBringsItsSettingsTheNextAdoptsThemAndChangesTravelBothWays() async throws {
        let cloud = MemoryCloud()
        let (first, firstSuite) = try mac()
        let (second, secondSuite) = try mac()
        defer {
            UserDefaults().removePersistentDomain(forName: firstSuite)
            UserDefaults().removePersistentDomain(forName: secondSuite)
        }
        first[Self.limit] = 200
        first[Self.folder] = "/Volumes/First"
        second[Self.limit] = 1000
        second[Self.folder] = "/Volumes/Second"
        let firstSync = SettingsSyncService(settings: first, uploadDelay: .milliseconds(10)) { cloud.backend() }
        let secondSync = SettingsSyncService(settings: second, uploadDelay: .milliseconds(10)) { cloud.backend() }
        defer {
            firstSync.stop()
            secondSync.stop()
        }

        first[AppSettings.syncSettings] = true
        firstSync.update()
        try await until { cloud.snapshots.count == 1 }
        second[AppSettings.syncSettings] = true
        secondSync.update()
        try await until { second[Self.limit] == 200 }
        #expect(second[Self.folder] == "/Volumes/Second", "folders stay on each Mac")

        second[Self.limit] = 300
        try await until { first[Self.limit] == 300 }
        second.reset(Self.limit)
        try await until { first[Self.limit] == 500 }
        #expect(first[Self.folder] == "/Volumes/First")
    }

    @Test func nothingSyncsWithoutAStore() throws {
        let (settings, suite) = try mac()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let sync = SettingsSyncService(settings: settings) { nil }
        settings[AppSettings.syncSettings] = true
        sync.update()
        #expect(sync.status == .unavailable)
        settings[AppSettings.syncSettings] = false
        sync.update()
        #expect(sync.status == .off)
    }
}

/// An iCloud that every backend made from it shares; publishing tells the other Macs.
@MainActor
private final class MemoryCloud {
    var snapshots: [String: SettingsSnapshot] = [:]
    private var backends: [MemoryBackend] = []

    func backend() -> MemoryBackend {
        let backend = MemoryBackend(cloud: self)
        backends.append(backend)
        return backend
    }

    func publish(_ snapshot: SettingsSnapshot, from sender: MemoryBackend) {
        snapshots[snapshot.device] = snapshot
        for backend in backends where backend !== sender {
            backend.onRemoteChange?()
        }
    }
}

@MainActor
private final class MemoryBackend: SettingsSyncBackend {
    let name = "memory"
    var onRemoteChange: (() -> Void)?
    private unowned let cloud: MemoryCloud

    init(cloud: MemoryCloud) {
        self.cloud = cloud
    }

    func start() {}

    func stop() {}

    func publish(_ snapshot: SettingsSnapshot) async throws {
        cloud.publish(snapshot, from: self)
    }

    func others(excluding device: String) async throws -> [SettingsSnapshot] {
        cloud.snapshots.values.filter { $0.device != device }
    }
}
