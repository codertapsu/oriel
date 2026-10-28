import AppKit
import SwiftUI

/// A tool of the app (PLAN §6.3). The app's `ModuleRegistry` activates the enabled ones lazily and
/// deactivates a module when the user turns it off; a deactivated module leaves no taps, observers or timers.
@MainActor
public protocol UtilityModule: AnyObject {
    static var id: ModuleID { get }
    var displayName: String { get }
    var requiredPermissions: Set<PermissionKind> { get }
    /// Items for the status menu, rebuilt each time the menu opens.
    var menuItems: [NSMenuItem] { get }
    /// The module's pane in Settings.
    var settingsPane: AnyView? { get }
    /// CLI verbs the module answers.
    var ipcCommands: [IPCCommandHandler] { get }
    func activate(context: ModuleContext) async
    func deactivate() async
}
