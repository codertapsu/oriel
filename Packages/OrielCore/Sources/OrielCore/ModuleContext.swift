import os

/// What a module gets when it is activated.
public struct ModuleContext: Sendable {
    public let services: ServiceContainer
    public let settings: SettingsStore
    public let log: Logger

    public init(services: ServiceContainer, settings: SettingsStore, log: Logger) {
        self.services = services
        self.settings = settings
        self.log = log
    }
}
