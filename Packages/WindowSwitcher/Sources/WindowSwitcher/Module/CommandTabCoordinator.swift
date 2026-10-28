import OrielCore
import os

/// Cmd-Tab takeover (PLAN §7.1.4): while a shortcut uses ⌘⇥ (or another combination the system binds), the
/// matching symbolic hot keys, found by enumeration, are turned off; they are turned back on when the
/// shortcut goes, on deactivation, at exit and on SIGTERM/SIGINT/SIGHUP (`SymbolicHotKeyGuard`), and at the
/// next activation after a crash or `kill -9`, because the ids are written to settings before they are
/// turned off.
final class CommandTabCoordinator {
    private let settings: SettingsStore
    private let control: any SymbolicHotKeyControlling
    private let hotKeyGuard: SymbolicHotKeyGuard
    private let log = Log.logger("switcher")
    private(set) var disabled: [Int32] = []

    init(settings: SettingsStore, control: any SymbolicHotKeyControlling, hotKeyGuard: SymbolicHotKeyGuard) {
        self.settings = settings
        self.control = control
        self.hotKeyGuard = hotKeyGuard
    }

    /// Turns back on what an earlier run left off. Call before `apply`.
    func restoreLeftovers() {
        let leftover = settings[SwitcherSettingKeys.disabledSymbolicHotKeys]
        guard !leftover.isEmpty else { return }
        for id in leftover {
            control.setSymbolicHotKey(id, enabled: true)
        }
        settings[SwitcherSettingKeys.disabledSymbolicHotKeys] = []
        log.notice("re-enabled \(leftover.count) system hot keys an earlier run left disabled")
    }

    /// Disables exactly the hot keys `shortcuts` collide with (none when `enabled` is false).
    func apply(shortcuts: [ShortcutSpec], enabled: Bool) {
        let target = enabled
            ? CommandTabTakeover.hotKeyIDs(in: control.symbolicHotKeys(), for: shortcuts, disabledByUs: Set(disabled))
            : []
        guard target != disabled else { return }
        let toEnable = Set(disabled).subtracting(target).sorted()
        let toDisable = Set(target).subtracting(disabled).sorted()
        // Recorded first, so a crash between the two steps is still repaired at the next activation.
        if settings[SwitcherSettingKeys.disabledSymbolicHotKeys] != target {
            settings[SwitcherSettingKeys.disabledSymbolicHotKeys] = target
        }
        hotKeyGuard.track(target, control: control)
        for id in toDisable {
            control.setSymbolicHotKey(id, enabled: false)
        }
        for id in toEnable {
            control.setSymbolicHotKey(id, enabled: true)
        }
        disabled = target
        log.notice("system hot keys taken over: \(target, privacy: .public)")
    }

    /// Gives every hot key back.
    func restore() {
        apply(shortcuts: [], enabled: false)
    }
}
