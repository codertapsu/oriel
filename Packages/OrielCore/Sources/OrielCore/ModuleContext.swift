import os

/// What a module gets when it is activated.
public struct ModuleContext: Sendable {
    public let services: ServiceContainer
    public let settings: SettingsStore
    public let log: Logger
    /// Opens Settings at the module's own pane.
    public let openSettings: @MainActor @Sendable () -> Void

    public init(
        services: ServiceContainer,
        settings: SettingsStore,
        log: Logger,
        openSettings: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.services = services
        self.settings = settings
        self.log = log
        self.openSettings = openSettings
    }
}
