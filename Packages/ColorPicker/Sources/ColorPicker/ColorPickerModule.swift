import AppKit
import OrielCore
import SwiftUI

/// Color Picker (PLAN §7.12): picks a colour off the screen and checks the contrast of two colours.
public final class ColorPickerModule: UtilityModule {
    public static let id: ModuleID = .colorPicker

    public let displayName = "Color Picker"

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
        "eyedropper"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context _: ModuleContext) async {}

    public func deactivate() async {}
}
