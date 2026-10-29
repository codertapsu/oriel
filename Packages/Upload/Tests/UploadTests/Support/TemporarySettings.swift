import Foundation
import OrielCore

/// Settings in a throwaway defaults domain, removed by `remove()`.
@MainActor
struct TemporarySettings {
    let suiteName = "com.codertapsu.oriel.tests.upload.\(UUID().uuidString)"
    let store: SettingsStore

    init() {
        store = SettingsStore(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
    }

    func remove() {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}
