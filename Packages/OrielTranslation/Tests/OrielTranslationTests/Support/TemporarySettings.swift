import Foundation
import OrielCore
import Testing

/// A `SettingsStore` on a throwaway UserDefaults suite; call `remove()` when done.
@MainActor
struct TemporarySettings {
    let name = "com.codertapsu.oriel.tests.translation.\(UUID().uuidString)"
    let store: SettingsStore

    init() throws {
        store = try SettingsStore(defaults: #require(UserDefaults(suiteName: name)))
    }

    func remove() {
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }
}
