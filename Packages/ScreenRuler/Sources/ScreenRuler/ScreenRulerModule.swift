import AppKit
import OrielCore
import os
import SharedUI
import SwiftUI

/// Screen Ruler (PLAN §7.13): measures on the screen, over every display at once. Measure Area reads a dragged
/// rectangle's size and position in points and pixels; Dimensions shows the distances from the pointer to the
/// nearest edges, found in a still picture of the screen, like xScope or PixelSnap; Guides places lines and measures
/// the gaps between them. ⌘C copies the measurement ("320 × 240 pt").
///
/// ⌃⇧M opens and closes it (Settings → Shortcuts). Dimensions needs Screen Recording, so the module lists no required
/// permission: the other modes work without it, and the ruler never asks unprompted. Nothing runs while the ruler is
/// closed.
public final class ScreenRulerModule: UtilityModule {
    public static let id: ModuleID = .screenRuler

    public let displayName = "Screen Ruler"

    /// ⌃⇧M, as asked for.
    static let shortcut = KeyCombo(keyCode: KeyCode.ansiM, modifiers: [.control, .shift])

    public private(set) var isActive = false
    private(set) var permissions: (any PermissionChecking)?
    private(set) var overlay: RulerOverlay?
    private var settings: SettingsStore?
    private let makeCapture: () -> any DisplayCapturing
    private let copier: ((String) -> Void)?
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = ScreenRulerSettingsModel(module: self)
    private let log = Log.logger("screen-ruler")

    public convenience init() {
        self.init(makeCapture: { ScreenCaptureKitCapture() })
    }

    /// - Parameters:
    ///   - makeCapture: what takes the still pictures; tests hand in a fake.
    ///   - copier: where ⌘C goes; nil for the general pasteboard.
    init(makeCapture: @escaping () -> any DisplayCapturing, copier: ((String) -> Void)? = nil) {
        self.makeCapture = makeCapture
        self.copier = copier
    }

    /// None: Dimensions uses Screen Recording when it is granted, and the other modes need nothing.
    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    public var menuItems: [NSMenuItem] {
        []
    }

    public var settingsPane: AnyView? {
        AnyView(ScreenRulerSettingsView(model: settingsModel))
    }

    public var proFeatures: [ProFeature] {
        ProFeature.screenRulerFeatures
    }

    public var settingsSymbol: String {
        "ruler"
    }

    public var guide: FeatureGuide? {
        .screenRuler
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    /// Screen Ruler (⌃⇧M, `oriel://ruler`), which opens the ruler or closes it.
    public var commands: [ToolCommand] {
        let command = ToolCommand(
            id: "openScreenRuler",
            title: "Screen Ruler",
            symbol: "ruler",
            group: .tools,
            defaultShortcut: Self.shortcut,
            route: "ruler"
        ) { [weak self] in
            self?.toggle()
        }
        return [command]
    }

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    /// The shortcut as text ("⌃⇧M"), for the Settings pane.
    var shortcutDescription: String? {
        commands.first.flatMap { currentSettings[$0.shortcutKey] }?.description
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        permissions = context.services.permissions
        settingsModel.refresh()
    }

    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        overlay?.close()
        overlay = nil
    }

    /// Opens the ruler over every display, or closes it.
    func toggle() {
        guard isActive, let settings, let permissions else {
            log.notice("The Screen Ruler was asked for while it is off")
            return
        }
        if let overlay, overlay.isOpen {
            overlay.close()
            return
        }
        let overlay = RulerOverlay(
            settings: settings,
            permissions: permissions,
            capture: makeCapture(),
            copier: copier ?? { Pasteboard.copy($0) }
        )
        overlay.onClose = { [weak self, weak overlay] in
            guard let self, self.overlay === overlay else { return }
            self.overlay = nil
            settingsModel.refresh()
        }
        self.overlay = overlay
        overlay.present()
    }
}
