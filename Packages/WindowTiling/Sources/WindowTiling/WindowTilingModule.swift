import AppKit
import ApplicationServices
import OrielCore
import os
import SharedUI
import SwiftUI

/// Window Tiling (PLAN §7.14): moves the focused window of the app in front to a half, a quarter, a third or two thirds
/// of its screen, maximizes or centers it, takes it to another display, makes it a step smaller or larger, and puts it
/// back, from Rectangle-like shortcuts (⌃⌥ with an arrow or a letter) and the status menu's Window Tiling submenu.
///
/// Needs Accessibility, which is what moves other apps' windows; without it a shortcut shows a notice that offers the
/// pane in System Settings. Every Accessibility call runs on the tool's AX actor (`WindowMover`). It installs no
/// observer, tap or timer: between two key presses it does nothing at all.
public final class WindowTilingModule: UtilityModule {
    public static let id: ModuleID = .windowTiling

    /// Arranges the app's focused window: the AX actor in the app, a stand-in in tests.
    typealias Arrange = @Sendable (TilingAction, Int32, [DisplayGeometry], TilingOptions) async -> TilingOutcome

    public let displayName = "Window Tiling"

    private let arrange: Arrange
    private let forget: @Sendable () async -> Void
    private let isTrusted: @MainActor () -> Bool
    private let frontmostApp: @MainActor () -> (pid: Int32, name: String?)?
    private let displays: @MainActor () -> [DisplayGeometry]
    private let feedback: any TilingFeedback
    private let log = Log.logger("tiling")

    public private(set) var isActive = false
    private var settings: SettingsStore?
    private var permissions: (any PermissionChecking)?
    /// The pane works before activation too, on the same defaults the app uses.
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = TilingSettingsModel(module: self)

    /// The module the app registers.
    public convenience init() {
        let mover = WindowMover()
        self.init(
            arrange: { action, pid, displays, options in
                await mover.arrange(action, pid: pid, displays: displays, options: options)
            },
            forget: { await mover.forgetAll() },
            isTrusted: { AXIsProcessTrusted() },
            frontmostApp: {
                NSWorkspace.shared.frontmostApplication.map { (pid: $0.processIdentifier, name: $0.localizedName) }
            },
            displays: { DisplayReader.current() },
            feedback: SystemTilingFeedback()
        )
    }

    /// For tests: a stand-in for the AX actor, the trust check, the app in front, the displays and the feedback.
    init(
        arrange: @escaping Arrange,
        forget: @escaping @Sendable () async -> Void = {},
        isTrusted: @escaping @MainActor () -> Bool,
        frontmostApp: @escaping @MainActor () -> (pid: Int32, name: String?)?,
        displays: @escaping @MainActor () -> [DisplayGeometry],
        feedback: any TilingFeedback,
        settings: SettingsStore? = nil
    ) {
        self.arrange = arrange
        self.forget = forget
        self.isTrusted = isTrusted
        self.frontmostApp = frontmostApp
        self.displays = displays
        self.feedback = feedback
        self.settings = settings
    }

    // MARK: UtilityModule

    /// Accessibility moves and resizes other apps' windows.
    public var requiredPermissions: Set<PermissionKind> {
        [.accessibility]
    }

    /// One command per action, each with its Rectangle-like default shortcut. They stay out of the status menu's
    /// list, which shows them in the Window Tiling submenu instead.
    public var commands: [ToolCommand] {
        TilingAction.allCases.map { action in
            action.command { [weak self] in self?.perform(action) }
        }
    }

    /// The Window Tiling submenu, while the tool is on.
    public var menuItems: [NSMenuItem] {
        guard isActive else { return [] }
        let settings = currentSettings
        let item = TilingMenu.item(
            shortcut: { settings[$0.shortcutKey] },
            hasOtherDisplays: displays().count > 1,
            perform: { [weak self] action in self?.perform(action) }
        )
        return [item]
    }

    public var settingsPane: AnyView? {
        AnyView(TilingSettingsView(model: settingsModel))
    }

    public var settingsSymbol: String {
        "rectangle.split.2x1"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        permissions = context.services.permissions
        settingsModel.refresh()
    }

    /// Takes down the notice and forgets every window; there is nothing else to stop.
    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        feedback.dismiss()
        await forget()
        settingsModel.refresh()
    }

    // MARK: Actions

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    var isAccessibilityTrusted: Bool {
        isTrusted()
    }

    /// The user's shortcut for an action, for the Settings pane.
    func shortcut(for action: TilingAction) -> KeyCombo? {
        currentSettings[action.shortcutKey]
    }

    /// Runs `action` on the focused window of the app in front. The main actor only reads the displays and the
    /// settings; the window is read and moved on the AX actor, and the outcome comes back here for the feedback.
    func perform(_ action: TilingAction) {
        guard isActive else {
            log.notice("a tiling shortcut was pressed while Window Tiling is off")
            return
        }
        guard isTrusted() else {
            askForAccessibility()
            return
        }
        guard let app = frontmostApp() else {
            feedback.respond(.beep)
            return
        }
        let displays = displays()
        let options = TilingSettings.options(in: currentSettings)
        let arrange = arrange
        Task { [weak self] in
            let outcome = await arrange(action, app.pid, displays, options)
            self?.finish(action, outcome: outcome, appName: app.name)
        }
    }

    func openAccessibilitySettings() {
        if let permissions {
            permissions.openSystemSettings(for: .accessibility)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func askForAccessibility() {
        feedback.askForAccessibility(paneName: PermissionKind.accessibility.settingsPaneName()) { [weak self] in
            self?.openAccessibilitySettings()
        }
    }

    private func finish(_ action: TilingAction, outcome: TilingOutcome, appName: String?) {
        switch outcome {
        case .moved, .unchanged, .noWindow:
            break
        case .skipped, .appDidNotRespond:
            log.notice("\(action.rawValue, privacy: .public): \(String(describing: outcome), privacy: .public)")
        }
        // Accessibility answers as if the app were silent once Oriel loses the permission; say what is really missing.
        if outcome == .appDidNotRespond, !isTrusted() {
            askForAccessibility()
            return
        }
        feedback.respond(TilingResponse.to(outcome, of: action, appName: appName))
    }
}
