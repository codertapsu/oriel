import AppKit
import OrielCore
import os
import SwiftUI

/// Activity Monitor (PLAN §7.11): the running apps, services and processes, and what they use: CPU, memory, energy,
/// disk and network, per process and for the Mac, with search, views, live graphs, details and Quit, Force Quit and
/// Send Signal behind confirmations.
///
/// It measures only while its window is open (CLAUDE.md rule 3): opening the window starts a `SamplingSession`, and
/// closing it stops the session and the history with it. Turned on but closed, it costs nothing. `oriel top` takes two
/// samples of its own.
public final class ActivityMonitorModule: UtilityModule {
    public static let id: ModuleID = .activityMonitor
    static let symbol = "gauge.with.dots.needle.67percent"

    public let displayName = "Activity Monitor"

    public private(set) var isActive = false
    private var settings: SettingsStore?
    /// Opens Settings at Activity Monitor; from the context the module was activated with.
    private var openSettings: (@MainActor @Sendable () -> Void)?
    private var window: ActivityWindowController?
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = ActivitySettingsModel(module: self)
    private let log = Log.logger("activity")

    public init() {}

    /// Nothing: what macOS does not share with the user's account is left out or comes from `ps`.
    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    public var menuItems: [NSMenuItem] {
        []
    }

    public var settingsPane: AnyView? {
        AnyView(ActivitySettingsView(model: settingsModel))
    }

    public var settingsSymbol: String {
        Self.symbol
    }

    /// Opens the window, or brings it to the front: from the status menu, a shortcut the user sets, or
    /// `oriel://activity`.
    public var commands: [ToolCommand] {
        let command = ToolCommand(
            id: "openActivityMonitor",
            title: "Activity Monitor",
            symbol: Self.symbol,
            group: .tools,
            route: "activity"
        ) { [weak self] in
            self?.openWindow()
        }
        return [command]
    }

    /// `top`: the busiest processes, as a table or JSON.
    public var ipcCommands: [IPCCommandHandler] {
        [TopCommand.handler()]
    }

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    var isWindowOpen: Bool {
        window?.window?.isVisible == true
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        openSettings = context.openSettings
        settingsModel.refresh()
    }

    /// Closes the window, which stops sampling.
    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        window?.close()
        window = nil
        settingsModel.refresh()
    }

    public func openWindow() {
        guard isActive, let settings else {
            log.notice("Activity Monitor was asked for while it is off")
            return
        }
        let controller = window ?? ActivityWindowController(settings: settings)
        controller.openSettings = { [weak self] in self?.openSettings?() }
        controller.onClose = { [weak self] in
            self?.window = nil
            self?.settingsModel.refresh()
        }
        window = controller
        controller.present()
        settingsModel.refresh()
    }
}
