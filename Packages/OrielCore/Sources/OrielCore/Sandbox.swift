import Foundation

/// Whether Oriel runs in the App Sandbox. The App Store edition does (PLAN §19): there, what needs another app's windows,
/// root, posted keystrokes or files the user did not grant gives way to what the sandbox allows.
public enum Sandbox {
    /// macOS sets the variable for every sandboxed process.
    public static let isActive = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
}
