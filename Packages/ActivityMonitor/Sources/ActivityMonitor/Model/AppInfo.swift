/// What `NSRunningApplication` says about a process that is an app, read on the main thread and handed to the sampler.
nonisolated struct AppInfo: Sendable, Equatable, Codable {
    let name: String
    let bundleID: String?
    /// The `.app` bundle, for icons and for grouping the helpers inside it.
    let bundlePath: String?
    /// In the Dock, with windows and a menu bar (`.regular`), rather than a menu-bar extra or background agent.
    let isRegular: Bool
}
