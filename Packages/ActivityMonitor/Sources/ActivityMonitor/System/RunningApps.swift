import AppKit

/// The running apps as `NSWorkspace` lists them, read on the main thread where it keeps them up to date.
enum RunningApps {
    /// Name, bundle and Dock status of every running app, by pid.
    static func catalog() -> [Int32: AppInfo] {
        var apps: [Int32: AppInfo] = [:]
        for app in NSWorkspace.shared.runningApplications where !app.isTerminated && app.processIdentifier > 0 {
            let bundle = app.bundleURL
            guard let name = app.localizedName ?? bundle?.deletingPathExtension().lastPathComponent else { continue }
            apps[app.processIdentifier] = AppInfo(
                name: name,
                bundleID: app.bundleIdentifier,
                bundlePath: bundle?.path(percentEncoded: false),
                isRegular: app.activationPolicy == .regular
            )
        }
        return apps
    }
}
