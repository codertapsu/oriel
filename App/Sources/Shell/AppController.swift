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

    private let hotkeys = CarbonHotkeyEngine()
    private(set) var shortcutErrors: [AppAction: String] = [:]
    private var statusMenu: StatusMenuController?
    private var settingsWindow: SettingsWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var ipcServer: IPCServer?
    private var settingsObserver: NSObjectProtocol?
    private let log = Log.logger("app")

    init() {
        hub = FeatureHub(settings: settings, permissions: permissions, keychain: keychain)
        registry = ModuleRegistry(
            settings: settings,
            services: ServiceContainer(keychain: keychain, permissions: permissions, textRecognizer: hub.textRecognizer),
            modules: hub.modules
        )
    }

    func start() {
        MainMenu.install { [weak self] in self?.showSettings() }
        if LaunchChecks.offerMoveToApplications() {
            return // the copy in Applications takes over once this one has quit
        }
        LaunchChecks.showArchitectureNotices(settings: settings)
        statusMenu = StatusMenuController(controller: self)
        hub.onRecordingChange = { [weak self] recording in self?.statusMenu?.showRecording(recording) }
        registerShortcuts()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: .main
        ) { [weak self] note in
            let name = note.userInfo?["key"] as? String ?? ""
            MainActor.assumeIsolated {
                if name.hasPrefix("shortcuts.") {
                    self?.registerShortcuts()
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
        }
    }

    func shutdown() async {
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
        guard let action = AppAction(url: url) else {
            log.error("unknown URL \(url.absoluteString, privacy: .private)")
            return
        }
        perform(action)
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

    /// Registers every action's global shortcut with Carbon; conflicts are kept for the Shortcuts pane.
    func registerShortcuts() {
        hotkeys.unregisterAll()
        shortcutErrors = [:]
        for action in AppAction.shortcutActions {
            guard let combo = settings[action.shortcutKey] else { continue }
            do {
                try hotkeys.register(combo, name: action.rawValue) { [weak self] in self?.perform(action) }
            } catch {
                shortcutErrors[action] = "\(combo) is taken by another app or by macOS."
            }
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
