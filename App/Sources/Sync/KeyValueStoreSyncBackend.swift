import Foundation
import OrielCore

/// Settings sync through iCloud key-value storage, the store meant for preferences. It needs the
/// `com.apple.developer.ubiquity-kvstore-identifier` entitlement, which a Developer ID app gets only with a provisioning
/// profile that has iCloud; without it the app uses `ICloudDriveSyncBackend` and never touches the store.
final class KeyValueStoreSyncBackend: SettingsSyncBackend {
    static let entitlement = "com.apple.developer.ubiquity-kvstore-identifier"
    private static let keyPrefix = "settings."

    static var isAvailable: Bool {
        Entitlements.value(of: entitlement) != nil
    }

    let name = "iCloud key-value storage"
    var onRemoteChange: (() -> Void)?
    private var observer: NSObjectProtocol?

    private var store: NSUbiquitousKeyValueStore {
        .default
    }

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onRemoteChange?() }
        }
        store.synchronize()
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    func publish(_ snapshot: SettingsSnapshot) async throws {
        try store.set(JSONEncoder().encode(snapshot), forKey: Self.keyPrefix + snapshot.device)
        store.synchronize()
    }

    func others(excluding device: String) async throws -> [SettingsSnapshot] {
        store.dictionaryRepresentation.compactMap { key, value in
            guard key.hasPrefix(Self.keyPrefix), key != Self.keyPrefix + device, let data = value as? Data else { return nil }
            return try? JSONDecoder().decode(SettingsSnapshot.self, from: data)
        }
    }
}
