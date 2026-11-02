import AppKit
import OrielCore
import os
import SharedUI
import SwiftUI

/// Color Picker (PLAN §7.12): picks a color off the screen with the system loupe and writes it in every format people
/// paste (HEX, CSS, OKLCH, Display P3, SwiftUI, AppKit and UIKit), keeps the latest picks and named palettes, exports a
/// palette as JSON, CSS variables or an Apple color list, and checks the contrast of two colors against WCAG 2.2, with
/// APCA as extra information.
///
/// ⌃⇧C picks (Settings → Shortcuts); the panel then opens with the color, already copied in the default format unless
/// Settings says otherwise. The loupe needs no permission. Nothing runs while the panel is closed, and `deactivate()`
/// closes it.
public final class ColorPickerModule: UtilityModule {
    public static let id: ModuleID = .colorPicker

    public let displayName = "Color Picker"

    /// ⌃⇧C, as asked for.
    static let pickShortcut = KeyCombo(keyCode: KeyCode.ansiC, modifiers: [.control, .shift])

    public private(set) var isActive = false
    private(set) var model: ColorPickerModel?
    private(set) var panel: ColorPanelController?
    private var settings: SettingsStore?
    private var openSettings: (@MainActor @Sendable () -> Void)?
    private var settingsObserver: (any NSObjectProtocol)?
    private var isSampling = false
    private let sampler: any ColorSampling
    private let directory: URL
    private let copier: ((String) -> Void)?
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = ColorPickerSettingsModel(module: self)
    private let log = Log.logger("color-picker")

    public convenience init() {
        self.init(sampler: ScreenColorSampler(), directory: Self.libraryDirectory)
    }

    /// - Parameters:
    ///   - sampler: the loupe; tests hand in a fake.
    ///   - directory: where `library.json` lives.
    ///   - copier: where copies go; nil for the general pasteboard.
    init(sampler: any ColorSampling, directory: URL, copier: ((String) -> Void)? = nil) {
        self.sampler = sampler
        self.directory = directory
        self.copier = copier
    }

    /// `~/Library/Application Support/Oriel/ColorPicker/<bundle ID>/`: the Debug build keeps its own library, as it
    /// keeps its own settings, so trying a build never touches the palettes of the one in use.
    static var libraryDirectory: URL {
        AppPaths.applicationSupport.appending(path: "ColorPicker", directoryHint: .isDirectory)
            .appending(path: Bundle.main.bundleIdentifier ?? "default", directoryHint: .isDirectory)
    }

    /// None: the loupe is the system's and needs no permission.
    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    public var menuItems: [NSMenuItem] {
        []
    }

    public var settingsPane: AnyView? {
        AnyView(ColorPickerSettingsView(model: settingsModel))
    }

    public var proFeatures: [ProFeature] {
        ProFeature.colorPickerFeatures
    }

    public var settingsSymbol: String {
        "eyedropper"
    }

    public var ipcCommands: [IPCCommandHandler] {
        []
    }

    /// Pick Color (⌃⇧C, `oriel://color/pick`) and Color Picker (`oriel://color`), which opens the panel.
    public var commands: [ToolCommand] {
        [
            ToolCommand(
                id: "pickColor",
                title: "Pick Color",
                symbol: "eyedropper",
                group: .tools,
                defaultShortcut: Self.pickShortcut,
                route: "color/pick"
            ) { [weak self] in
                self?.pick(.current)
            },
            ToolCommand(
                id: "openColorPicker",
                title: "Color Picker",
                symbol: "paintpalette",
                group: .tools,
                route: "color"
            ) { [weak self] in
                self?.togglePanel()
            },
        ]
    }

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    /// The pick shortcut as text ("⌃⇧C"), for the Settings pane.
    var pickShortcutDescription: String? {
        commands.first.flatMap { currentSettings[$0.shortcutKey] }?.description
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        openSettings = context.openSettings
        let model = ColorPickerModel(store: ColorStore(directory: directory), settings: context.settings)
        model.onChange = { [weak self] in self?.modelChanged() }
        self.model = model
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: context.settings, queue: .main
        ) { [weak self] note in
            let name = note.userInfo?["key"] as? String
            MainActor.assumeIsolated { self?.settingChanged(name) }
        }
        await model.load()
    }

    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        panel?.close()
        panel = nil
        await model?.flush()
        model = nil
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
        settingsModel.refresh()
    }

    /// Starts the loupe for one of the colors. A pick for the current color then opens the panel with it, copied when
    /// Settings says so; a pick for the contrast checker opens its tab. Every pick goes into Recent.
    func pick(_ target: ColorPanelController.PickTarget) {
        guard isActive, let model else {
            log.notice("A color pick was asked for while the Color Picker is off")
            return
        }
        guard !isSampling else { return }
        isSampling = true
        Task {
            let color = await sampler.sample()
            isSampling = false
            guard let color, isActive else { return }
            let panel = panelController(for: model)
            switch target {
            case .current:
                model.pick(color)
                if currentSettings[ColorPickerSettings.copiesOnPick] {
                    panel.copy(model.defaultFormat)
                }
                panel.show(tab: .color)
            case .contrastText, .contrastBackground:
                model.change { library in
                    library.record(color, limit: model.historyLimit)
                    if target == .contrastText {
                        library.contrastText = color
                    } else {
                        library.contrastBackground = color
                    }
                }
                panel.show(tab: .contrast)
            }
        }
    }

    /// Opens the panel, or brings it forward; closes it when it is already in front with the keyboard.
    func togglePanel() {
        guard isActive, let model else {
            log.notice("The Color Picker panel was asked for while the Color Picker is off")
            return
        }
        let panel = panelController(for: model)
        if panel.isVisible, panel.isKey {
            panel.close()
        } else {
            panel.show()
        }
    }

    private func panelController(for model: ColorPickerModel) -> ColorPanelController {
        if let panel {
            return panel
        }
        let controller = ColorPanelController(model: model)
        controller.pick = { [weak self] target in self?.pick(target) }
        controller.openSettings = { [weak self] in self?.openSettings?() }
        if let copier {
            controller.copier = copier
        }
        panel = controller
        return controller
    }

    private func modelChanged() {
        panel?.refresh()
        settingsModel.refresh()
    }

    private func settingChanged(_ name: String?) {
        guard let name, name.hasPrefix(ColorPickerSettings.prefix) else { return }
        if name == ColorPickerSettings.historySize.name {
            model?.applyHistoryLimit()
        }
        panel?.refresh()
    }
}
