import AppKit
import ApplicationServices
import OrielCore
import os
import SharedUI
import SwiftUI

/// The window switcher (PLAN §1.2, §7.1): an AltTab-class switcher over every window, including minimized,
/// hidden and other-Space ones, with up to nine shortcuts, three styles, search, previews, hover actions,
/// three-finger swipes, Cmd-Tab takeover and the `oriel windows …` CLI verbs.
///
/// It also shows an app's windows next to its Dock icon and the number of windows on Dock icons (PLAN §7.1.12), from
/// the same windows, also while the switcher itself is off.
///
/// Needs Accessibility; Screen Recording is optional and only adds thumbnails and previews. While active it
/// runs one event tap (only while the switcher is on) and AX and workspace observers, and no timers;
/// `deactivate()` removes all of it and gives Cmd-Tab back.
public final class WindowSwitcherModule: UtilityModule {
    public static let id: ModuleID = .windowSwitcher

    public let displayName = "Window Switcher"

    /// Accessibility only: Screen Recording is optional (thumbnails and the preview).
    public var requiredPermissions: Set<PermissionKind> {
        [.accessibility]
    }

    private let sourceFactory: @MainActor (_ observesChanges: Bool) -> any WindowSource
    private let hotKeys: any SymbolicHotKeyControlling
    private let hotKeyGuard: SymbolicHotKeyGuard
    private let isTrusted: @MainActor () -> Bool
    private let log = Log.logger("switcher")

    private var settings: SettingsStore?
    private var runtime: SwitcherRuntime?
    private var commandTab: CommandTabCoordinator?
    private var settingsObserver: (any NSObjectProtocol)?
    private let trust = AccessibilityTrustObserver()
    private var isActive = false
    private var isApplying = false
    private var needsApply = false
    /// The pane works before activation too, on the same defaults the app uses.
    private lazy var standaloneSettings = SettingsStore()

    /// The module the app registers.
    public convenience init() {
        self.init(
            sourceFactory: { SystemWindowSource(observesChanges: $0) },
            hotKeys: SystemSymbolicHotKeys(),
            hotKeyGuard: .shared,
            isTrusted: { AXIsProcessTrusted() }
        )
    }

    /// For tests: fake windows, fake hot keys, a private guard.
    init(
        sourceFactory: @escaping @MainActor (_ observesChanges: Bool) -> any WindowSource,
        hotKeys: any SymbolicHotKeyControlling,
        hotKeyGuard: SymbolicHotKeyGuard,
        isTrusted: @escaping @MainActor () -> Bool,
        settings: SettingsStore? = nil
    ) {
        self.sourceFactory = sourceFactory
        self.hotKeys = hotKeys
        self.hotKeyGuard = hotKeyGuard
        self.isTrusted = isTrusted
        self.settings = settings
    }

    /// Whether the module is running: active, trusted, and the switcher or a Dock feature on.
    var isRunning: Bool {
        runtime != nil
    }

    /// Whether the switcher itself runs, not only the Dock's features.
    var isSwitcherRunning: Bool {
        runtime?.isSwitcherOn == true
    }

    // MARK: UtilityModule

    /// "Show Window Switcher" while the switcher runs.
    public var menuItems: [NSMenuItem] {
        guard isSwitcherRunning else { return [] }
        let show = ActionMenuItem("Show Window Switcher", symbol: "rectangle.on.rectangle") { [weak self] in
            self?.show(shortcutIndex: 0)
        }
        return [show]
    }

    /// The Window Switcher pane of Settings.
    public var settingsPane: AnyView? {
        AnyView(SwitcherSettingsView(settings: settings ?? standaloneSettings))
    }

    public var settingsSymbol: String {
        "rectangle.stack"
    }

    /// `windows list|focus|close|minimize` and, in Debug builds, `debug open-switcher`.
    public var ipcCommands: [IPCCommandHandler] {
        WindowCommands.handlers(for: self)
    }

    /// Restores system hot keys a crashed run left off, then starts the switcher if it is enabled and
    /// Accessibility is granted; otherwise it waits for the grant without polling.
    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        let coordinator = CommandTabCoordinator(settings: context.settings, control: hotKeys, hotKeyGuard: hotKeyGuard)
        coordinator.restoreLeftovers()
        commandTab = coordinator
        settingsObserver = NotificationCenter.default
            .addObserver(forName: SettingsStore.didChangeNotification, object: nil, queue: .main) { [weak self] note in
                guard let key = note.userInfo?["key"] as? String, key.hasPrefix(SwitcherSettingKeys.prefix),
                      key != SwitcherSettingKeys.disabledSymbolicHotKeys.name
                else { return }
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { await self.applySettings() }
                }
            }
        await applySettings()
    }

    /// Stops the tap, the observers and the caches, and gives Cmd-Tab back.
    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
        trust.stop()
        await stopRuntime()
        commandTab = nil
    }

    // MARK: API

    /// Every window the switcher would list, most recently used first. Works before activation too, with a
    /// one-shot read that installs no observers.
    public func windows(includeOtherSpaces: Bool) async -> [WindowInfo] {
        let entries = await currentEntries().entries
        return entries.filter { includeOtherSpaces || $0.info.isOnCurrentSpace }.map(\.info)
    }

    /// Brings the window front and key, switching Space if needed (PLAN §7.1.3).
    public func focus(windowID: UInt32) async -> Bool {
        let (entries, source, store) = await currentEntries()
        guard let entry = entries.first(where: { $0.id == windowID }) else { return false }
        let focused = await source.focus(entry)
        if focused {
            await store.noteFocused(windowID)
        }
        return focused
    }

    /// Closes, minimizes or toggles full screen of a window through Accessibility.
    public func perform(_ action: WindowAction, windowID: UInt32) async -> Bool {
        let (entries, source, _) = await currentEntries()
        guard let entry = entries.first(where: { $0.id == windowID }) else { return false }
        return await source.perform(action, on: entry)
    }

    /// Debug hook: opens the switcher as if shortcut `shortcutIndex` (0-based) were pressed, in keep-open mode.
    public func show(shortcutIndex: Int) {
        guard let runtime, runtime.isSwitcherOn else {
            log.notice("show(shortcutIndex:) ignored: the switcher is not running")
            return
        }
        runtime.controller.open(shortcutIndex: shortcutIndex)
    }

    // MARK: Private

    /// Applies the settings, one pass at a time: changes that arrive during a pass (a slider being dragged)
    /// collapse into one more pass with the newest values, so an older pass can never win.
    private func applySettings() async {
        needsApply = true
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        while needsApply {
            needsApply = false
            await applyCurrentSettings()
        }
    }

    private func applyCurrentSettings() async {
        guard isActive, let settings else { return }
        let configuration = SwitcherConfiguration.load(from: settings)
        guard configuration.needsRuntime else {
            trust.stop()
            await stopRuntime()
            return
        }
        guard isTrusted() else {
            await stopRuntime()
            if !trust.isObserving {
                log.notice("waiting for Accessibility before starting the switcher")
                trust.start { [weak self] in
                    guard let self else { return }
                    Task { await self.applySettings() }
                }
            }
            return
        }
        trust.stop()
        if let runtime {
            await runtime.apply(configuration)
        } else {
            let runtime = SwitcherRuntime(source: sourceFactory(true), configuration: configuration)
            self.runtime = runtime
            runtime.start(configuration: configuration)
        }
        commandTab?.apply(shortcuts: configuration.shortcuts, enabled: configuration.isEnabled && configuration.takesOverCommandTab)
    }

    private func stopRuntime() async {
        commandTab?.restore()
        guard let runtime else { return }
        self.runtime = nil
        await runtime.stop()
    }

    /// The running store's windows, refreshed; or a one-shot read when the switcher is not running.
    private func currentEntries() async -> (entries: [WindowEntry], source: any WindowSource, store: WindowStore) {
        if let runtime {
            await runtime.store.refresh()
            return await (runtime.store.entries, runtime.source, runtime.store)
        }
        let exceptions = settings.map { $0[SwitcherSettingKeys.exceptions] } ?? AppException.defaults
        let source = sourceFactory(false)
        let store = WindowStore(source: source, rules: EligibilityRules(exceptions: exceptions))
        await store.bootstrap()
        return await (store.entries, source, store)
    }
}
