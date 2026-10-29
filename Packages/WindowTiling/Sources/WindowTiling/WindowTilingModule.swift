import AppKit
import OrielCore
import SwiftUI

/// Window Tiling (PLAN §7.14): moves the front window to a half, a third, a quarter or another display.
public final class WindowTilingModule: UtilityModule {
    public static let id: ModuleID = .windowTiling

    public let displayName = "Window Tiling"

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
        "rectangle.split.2x1"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context _: ModuleContext) async {}

    public func deactivate() async {}
}
