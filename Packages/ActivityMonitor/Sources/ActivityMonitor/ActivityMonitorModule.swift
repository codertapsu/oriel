import AppKit
import OrielCore
import SwiftUI

/// Activity Monitor (PLAN §7.11): the running apps, services and processes, and what they use.
public final class ActivityMonitorModule: UtilityModule {
    public static let id: ModuleID = .activityMonitor

    public let displayName = "Activity Monitor"

    public init() {}

    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    public var menuItems: [NSMenuItem] {
        []
    }

    public var settingsPane: AnyView? {
        nil
    }

    public var settingsSymbol: String {
        "gauge.with.dots.needle.67percent"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context _: ModuleContext) async {}

    public func deactivate() async {}
}
