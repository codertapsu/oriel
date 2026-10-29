import Foundation

/// One Mac's synced settings, as it writes them to iCloud (PLAN §7.16). Each Mac writes only its own snapshot, so two
/// Macs never write the same record; each reads the others' and keeps, per setting, the newest change.
public nonisolated struct SettingsSnapshot: Codable, Sendable, Equatable {
    /// A setting's value as `SettingsStore` stores it, and when it last changed on the Mac that wrote it.
    public struct Entry: Codable, Sendable, Equatable {
        /// The stored JSON, or nil when the setting was reset to its default.
        public var value: Data?
        public var modified: Date

        public init(value: Data?, modified: Date) {
            self.value = value
            self.modified = modified
        }
    }

    public static let currentVersion = 1

    public var version: Int
    /// A random identifier of the Mac that wrote it, kept on that Mac; never its serial number.
    public var device: String
    /// The Mac's name, for Settings ("MacBook Pro").
    public var deviceName: String
    public var written: Date
    public var entries: [String: Entry]

    public init(device: String, deviceName: String, written: Date, entries: [String: Entry]) {
        version = Self.currentVersion
        self.device = device
        self.deviceName = deviceName
        self.written = written
        self.entries = entries
    }
}
