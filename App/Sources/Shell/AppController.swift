import AppKit
import Hotkeys
import IPC
import OrielCore
import os
import Permissions
import SharedUI

/// The app shell (PLAN §6.1): settings, permissions, global shortcuts, the CLI socket, the module registry, the
/// status menu and the windows. Features live behind `FeatureHub`.
@MainActor
final class AppController {
    let settings = SettingsStore()
    let permissions = PermissionCenter()
    /// Keyed by bundle ID, so a Debug build never reads, or prompts for, the installed app's items.
    let keychain = Bundle.main.bundleIdentifier.map { KeychainStore(prefix: $0) } ?? KeychainStore()
    let hub: FeatureHub
    let registry: ModuleRegistry
    let sync: SettingsSyncService

    private let hotkeys = CarbonHotkeyEngine()
    /// Shortcut conflicts by action or command id, for the Shortcuts pane.
    private(set) var shortcutErrors: [String: String] = [:]
    private var statusMenu: StatusMenuController?
    private var settingsWindow: SettingsWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var ipcServer: IPCServer?
    private var settingsObserver: NSObjectProtocol?
    private let log = Log.logger("app")

    init() {
        hub = FeatureHub(settings: settings, permissions: permissions, keychain: keychain)
        sync = SettingsSyncService(settings: settings)
        registry = ModuleRegistry(
            settings: settings,
            services: ServiceContainer(keychain: keychain, permissions: permissions, textRecognizer: hub.textRecognizer),
            modules: hub.modules
        )
    }

    /// Starts everything; `opensWindow` shows Settings once started, unless onboarding is still to come, which shows instead.
    /// `urls`, what Oriel was launched to open, are opened last, unless this copy is moving to Applications.
    func start(opensWindow: Bool = false, opening urls: [URL] = []) {
        IntentContext.controller = self
        MainMenu.install { [weak self] in self?.showSettings() }
        if LaunchChecks.offerMoveToApplications() {
            return // the copy in Applications takes over once this one has quit
        }
        LaunchChecks.showArchitectureNotices(settings: settings)
        statusMenu = StatusMenuController(controller: self)
        hub.onRecordingChange = { [weak self] recording in self?.statusMenu?.showRecording(recording) }
        registry.openSettings = { [weak self] id in self?.showSettings(tab: id.rawValue) }
        registry.enableNewDefaultModules()
        registerShortcuts()
        sync.update()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: .main
        ) { [weak self] note in
            let name = note.userInfo?["key"] as? String ?? ""
            let fromSync = note.userInfo?["origin"] as? String == "sync"
            MainActor.assumeIsolated {
                if name.hasPrefix("shortcuts.") || name == AppSettings.enabledModules.name {
                    self?.registerShortcuts()
                }
                if name == AppSettings.enabledModules.name, fromSync {
                    Task { await self?.registry.applyEnabledModules() }
                }
                if name == AppSettings.syncSettings.name {
                    self?.sync.update()
                }
            }
        }
        startIPC()
        Task {
            await bootstrapImporter.importAvailable()
            await registry.activateEnabledModules()
        }
        if !settings[AppSettings.onboardingCompleted] {
            showOnboarding()
        } else if opensWindow {
            showSettings()
        }
        for url in urls {
            handle(url)
        }
    }

    func shutdown() async {
        sync.stop()
        await registry.deactivateAll()
        await hub.shutdown()
        ipcServer?.stop()
        hotkeys.unregisterAll()
    }

    // MARK: Actions

    func perform(_ action: AppAction) {
        switch action {
        case .showSettings: showSettings()
        case .showOnboarding: showOnboarding()
        case .quit: NSApp.terminate(nil)
        default: Task { await hub.perform(action) }
        }
    }

    func handle(_ url: URL) {
        if url.isFileURL {
            hub.open(fileAt: url)
            return
        }
        if let action = AppAction(url: url) {
            perform(action)
        } else if let route = AppAction.route(of: url), let command = commands.first(where: { $0.route == route }) {
            command.perform()
        } else {
            log.error("unknown URL \(url.absoluteString, privacy: .private)")
        }
    }

    /// Runs an app action or a command by its id, for Run Oriel Command; false when there is none, as for a command
    /// of a tool that is turned off.
    func run(commandID id: String) -> Bool {
        if let action = AppAction(rawValue: id) {
            perform(action)
            return true
        }
        guard let command = commands.first(where: { $0.id == id }) else { return false }
        command.perform()
        return true
    }

    /// Every command the features and the turned-on tools offer (PLAN §6.5).
    var commands: [ToolCommand] {
        hub.commands + registry.commands
    }

    func showSettings(tab: String? = nil) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(controller: self)
        }
        settingsWindow?.show(tab: tab)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(permissions: permissions) { [weak self] in
                self?.settings[AppSettings.onboardingCompleted] = true
                self?.onboardingWindow = nil
            }
        }
        onboardingWindow?.show()
    }

    var bootstrapImporter: BootstrapImporter {
        BootstrapImporter(settings: settings, keychain: keychain) { [weak self] providers, defaultProvider in
            self?.hub.applyBootstrap(providers: providers, defaultProvider: defaultProvider)
        }
    }

    func capabilities() async -> Capabilities {
        await CapabilitiesProbe.current(permissions: permissions, translationPair: hub.translationPair)
    }

    // MARK: Shortcuts

    /// Registers the global shortcuts of every action and command with Carbon; conflicts are kept for the Shortcuts
    /// pane. A tool's commands are registered only while the tool is on.
    func registerShortcuts() {
        hotkeys.unregisterAll()
        shortcutErrors = [:]
        for action in AppAction.shortcutActions {
            register(settings[action.shortcutKey], name: action.rawValue) { [weak self] in self?.perform(action) }
        }
        for command in commands {
            register(settings[command.shortcutKey], name: command.id, handler: command.perform)
        }
    }

    private func register(_ combo: KeyCombo?, name: String, handler: @escaping @MainActor () -> Void) {
        guard let combo else { return }
        do {
            try hotkeys.register(combo, name: name, handler: handler)
        } catch {
            shortcutErrors[name] = "\(combo) is taken by another app or by macOS."
        }
    }

    // MARK: CLI

    private func startIPC() {
        let router = IPCRouter { [weak self] in self?.ipcCommands ?? [] }
        let server = IPCServer { request in await router.handle(request) }
        do {
            try server.start()
            ipcServer = server
        } catch {
            log.error("the CLI socket could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var ipcCommands: [IPCCommandHandler] {
        let capabilities = IPCCommandHandler(verb: "debug.capabilities", usage: "debug capabilities --json") { [weak self] request in
            guard let self else { return .failure(request, "Oriel is shutting down.") }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = await (try? encoder.encode(capabilities())) ?? Data()
            return .ok(request, String(data: data, encoding: .utf8) ?? "{}")
        }
        return [capabilities] + hub.ipcCommands + registry.ipcCommands
    }
}
