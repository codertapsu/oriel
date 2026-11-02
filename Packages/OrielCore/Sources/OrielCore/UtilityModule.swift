import AppKit
import SwiftUI

/// A tool of the app (PLAN §6.3). The app's `ModuleRegistry` activates the enabled ones lazily and
/// deactivates a module when the user turns it off; a deactivated module leaves no taps, observers or timers.
///
/// A tool plugs in without changes to the app: its `commands` get shortcuts, menu items and `oriel://` URLs, its
/// `settingsPane` a tab in Settings, and its `ipcCommands` CLI verbs.
@MainActor
public protocol UtilityModule: CommandProviding {
    static var id: ModuleID { get }
    var displayName: String { get }
    var requiredPermissions: Set<PermissionKind> { get }
    /// Extra items for the status menu, rebuilt each time the menu opens; the module's commands are listed already.
    var menuItems: [NSMenuItem] { get }
    /// The module's pane in Settings.
    var settingsPane: AnyView? { get }
    /// The SF Symbol of its Settings tab.
    var settingsSymbol: String { get }
    /// CLI verbs the module answers.
    var ipcCommands: [IPCCommandHandler] { get }
    /// What only Oriel Pro unlocks in the module (PLAN §19).
    var proFeatures: [ProFeature] { get }
    func activate(context: ModuleContext) async
    func deactivate() async
}

public extension UtilityModule {
    /// None unless the module declares some. Their shortcuts are registered only while the module is turned on.
    var commands: [ToolCommand] {
        []
    }

    var settingsSymbol: String {
        "puzzlepiece.extension"
    }

    var proFeatures: [ProFeature] {
        []
    }
}
