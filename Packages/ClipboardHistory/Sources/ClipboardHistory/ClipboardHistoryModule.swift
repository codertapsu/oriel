import AppKit
import OrielCore
import os
import SharedUI
import SwiftUI

/// Clipboard History (PLAN §7.9): keeps what is copied — text, links, colors, images, files and other data —
/// encrypted on this Mac, and opens a panel on its shortcut (⌥V) to search, preview, pin, reorder, delete and paste
/// an item straight into the app in front.
///
/// Oriel's own copies, such as screenshots, are always kept. Other apps' copies need macOS's Paste from Other Apps
/// permission. Changes are noticed without polling (`PasteboardWatcher`), and `deactivate()` removes every monitor and
/// observer.
public final class ClipboardHistoryModule: UtilityModule {
    public static let id: ModuleID = .clipboardHistory
    /// The keychain service holding the history's key, for Uninstall.
    public static let keychainService = ClipboardVault.keychainService

    public let displayName = "Clipboard History"

    /// The panel's default shortcut (PLAN §7.9).
    static let defaultShortcut = KeyCombo(keyCode: KeyCode.ansiV, modifiers: .option)

    /// Opens Settings at Clipboard History; from the context the module was activated with.
    private var openSettings: (@MainActor @Sendable () -> Void)?

    public private(set) var isActive = false
    private(set) var recorder: ClipboardRecorder?
    private var settings: SettingsStore?
    private var permissions: (any PermissionChecking)?
    private var indexer: ClipboardTextIndexer?
    private var panel: ClipboardPanelController?
    /// Why the history could not open (the keychain could not be read), for Settings.
    private(set) var failure: String?
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = ClipboardSettingsModel(module: self)
    private let log = Log.logger("clipboard")

    public init() {}

    /// Nothing is required: Accessibility lets it paste and Paste from Other Apps lets it read other apps' copies, and
    /// without either it still keeps Oriel's own copies and puts items back on the clipboard.
    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    /// "Pause Clipboard History" or "Resume Clipboard History" while active.
    public var menuItems: [NSMenuItem] {
        guard isActive, let recorder else { return [] }
        let paused = recorder.isPaused
        let item = ActionMenuItem(
            paused ? "Resume Clipboard History" : "Pause Clipboard History",
            symbol: paused ? "play.circle" : "pause.circle"
        ) { [weak self] in
            self?.setPaused(!paused)
        }
        return [item]
    }

    public var settingsPane: AnyView? {
        AnyView(ClipboardSettingsView(model: settingsModel))
    }

    public var settingsSymbol: String {
        "list.clipboard"
    }

    /// Opens or closes the panel. The id is the one the shortcut had as an app action, so a shortcut set before keeps
    /// working, and so does `oriel://clipboard`.
    public var commands: [ToolCommand] {
        let command = ToolCommand(
            id: "showClipboardHistory",
            title: "Clipboard History",
            symbol: "list.clipboard",
            group: .library,
            defaultShortcut: Self.defaultShortcut,
            route: "clipboard"
        ) { [weak self] in
            self?.togglePanel()
        }
        return [command]
    }

    /// The panel's shortcut as text ("⌥V"), for the Settings pane.
    var shortcutDescription: String? {
        commands.first.flatMap { currentSettings[$0.shortcutKey] }?.description
    }

    /// `debug clipboard`: the state, never the contents.
    public var ipcCommands: [IPCCommandHandler] {
        let command = IPCCommandHandler(verb: "debug.clipboard", usage: "debug clipboard [--json]") { [weak self] request in
            guard let self else { return .failure(request, "Oriel is shutting down.") }
            return await status(request)
        }
        return [command]
    }

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    var store: ClipboardStore? {
        recorder?.store
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        permissions = context.services.permissions
        openSettings = context.openSettings
        do {
            let key = try ClipboardVault.key(in: context.services.keychain)
            let store = ClipboardStore(directory: AppPaths.clipboardHistory, vault: ClipboardVault(key: key))
            await store.prepare()
            _ = try? await store.prune(ClipboardSettings.limits(in: context.settings))
            let recorder = ClipboardRecorder(store: store, settings: context.settings, permissions: context.services.permissions)
            recorder.onChange = { [weak self] in self?.historyChanged() }
            recorder.onImageAdded = { [weak self] in self?.indexer?.run() }
            recorder.start()
            self.recorder = recorder
            if let recognizer = context.services.textRecognizer {
                let indexer = ClipboardTextIndexer(store: store, recognizer: recognizer)
                indexer.onIndexed = { [weak self] in self?.historyChanged() }
                indexer.run()
                self.indexer = indexer
            }
            failure = nil
        } catch {
            failure = "Clipboard History could not open, because the keychain could not be read: \(error.localizedDescription)"
            log.error("Clipboard History could not open: \(error.localizedDescription, privacy: .public)")
        }
        historyChanged()
    }

    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        panel?.close()
        panel = nil
        indexer?.stop()
        indexer = nil
        recorder?.stop()
        recorder = nil
        historyChanged()
    }

    /// The global shortcut: opens the panel over the app in front, or closes it.
    public func togglePanel() {
        guard isActive, let recorder, let settings, let permissions else {
            if let failure {
                Toast.show(failure, symbol: "exclamationmark.triangle", duration: .seconds(4))
            }
            log.notice("The clipboard history panel was asked for while Clipboard History is off or could not open")
            return
        }
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        let controller = panel ?? ClipboardPanelController(recorder: recorder, settings: settings, permissions: permissions)
        controller.openSettings = { [weak self] in self?.openSettings?() }
        controller.onHistoryChanged = { [weak self] in self?.settingsModel.refresh() }
        panel = controller
        controller.show(target: NSWorkspace.shared.frontmostApplication)
    }

    func setPaused(_ paused: Bool) {
        if let recorder {
            recorder.setPaused(paused)
        } else {
            currentSettings[ClipboardSettings.isPaused] = paused
        }
    }

    func openPasteboardSettings() {
        permissions?.openSystemSettings(for: .pasteboard)
    }

    private func historyChanged() {
        panel?.refresh()
        settingsModel.refresh()
    }

    private func status(_ request: IPCRequest) async -> IPCResponse {
        let index = await store?.index()
        let report: [String: String] = await [
            "active": String(isActive),
            "open": String(failure == nil && recorder != nil),
            "watching": String(recorder?.isWatching ?? false),
            "paused": String(currentSettings[ClipboardSettings.isPaused]),
            "access": (recorder?.access ?? .current).rawValue,
            "missedCopies": String(recorder?.missedCopies ?? 0),
            "items": String(index?.count ?? 0),
            "pinned": String(index?.pinned.count ?? 0),
            "bytes": String(store?.diskUsage() ?? 0),
        ]
        guard request.flag("json") else {
            return .ok(request, report.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        }
        let data = (try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return .ok(request, String(data: data, encoding: .utf8) ?? "{}")
    }
}
