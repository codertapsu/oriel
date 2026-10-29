import OrielCore

/// Where this Mac's settings snapshot goes and the other Macs' come from (PLAN §7.16).
protocol SettingsSyncBackend: AnyObject {
    /// For Settings: "iCloud key-value storage" or "iCloud Drive".
    var name: String { get }
    /// Called when another Mac's snapshot may have changed.
    var onRemoteChange: (() -> Void)? { get set }
    func start() throws
    func stop()
    func publish(_ snapshot: SettingsSnapshot) async throws
    func others(excluding device: String) async throws -> [SettingsSnapshot]
}
