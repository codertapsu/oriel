import AppKit
import OrielCore
import SwiftUI

/// Disk Space Analyzer (PLAN §7.10): where the space on each drive goes, and safe ways to get it back.
public final class DiskAnalyzerModule: UtilityModule {
    public static let id: ModuleID = .diskAnalyzer

    public let displayName = "Disk Space Analyzer"

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
        "internaldrive"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context _: ModuleContext) async {}

    public func deactivate() async {}
}
