import ServiceManagement

/// Launch at login through `SMAppService.mainApp` (PLAN §5.2): no helper app, no LaunchAgent plist.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// The user still has to allow it in System Settings → General → Login Items when macOS asks.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
