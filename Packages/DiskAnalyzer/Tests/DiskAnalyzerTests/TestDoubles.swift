@testable import DiskAnalyzer
import Foundation
import OrielCore
import Testing

extension Fixtures {
    /// Settings for a test, kept in memory.
    @MainActor static func memorySettings() throws -> SettingsStore {
        try SettingsStore(defaults: #require(MemoryDefaults(suiteName: nil)))
    }

    /// Settings kept in memory, so tests never write a preferences file.
    final nonisolated class MemoryDefaults: UserDefaults, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Any] = [:]

        /// A nil suite searches the standard domains, but every read and write below is overridden.
        override init?(suiteName _: String?) {
            super.init(suiteName: nil)
        }

        override func object(forKey key: String) -> Any? {
            lock.withLock { values[key] }
        }

        override func data(forKey key: String) -> Data? {
            lock.withLock { values[key] as? Data }
        }

        override func set(_ value: Any?, forKey key: String) {
            lock.withLock { values[key] = value }
        }

        override func removeObject(forKey key: String) {
            lock.withLock { values[key] = nil }
        }

        override func dictionaryRepresentation() -> [String: Any] {
            lock.withLock { values }
        }
    }

    /// Permissions that are never asked for.
    @MainActor
    final class NoPermissions: PermissionChecking {
        func status(of _: PermissionKind) -> PermissionStatus {
            .notDetermined
        }

        func request(_: PermissionKind) async -> PermissionStatus {
            .notDetermined
        }

        func openSystemSettings(for _: PermissionKind) {}
    }
}
