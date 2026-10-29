import AppKit
import OrielCore
import SwiftUI

/// Screen Ruler (PLAN §7.13): measures distances and sizes on the screen.
public final class ScreenRulerModule: UtilityModule {
    public static let id: ModuleID = .screenRuler

    public let displayName = "Screen Ruler"

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
        "ruler"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context _: ModuleContext) async {}

    public func deactivate() async {}
}
