import AppKit
import OrielCore
import os

/// Activates the enabled utility modules lazily and deactivates a module the user turns off, which then leaves
/// no taps, observers or timers behind (PLAN §6.3).
@MainActor
final class ModuleRegistry {
    private let settings: SettingsStore
    private let services: ServiceContainer
    private let modules: [any UtilityModule]
    private var active: Set<ModuleID> = []

    init(settings: SettingsStore, services: ServiceContainer, modules: [any UtilityModule]) {
        self.settings = settings
        self.services = services
        self.modules = modules
    }

    var all: [any UtilityModule] {
        modules
    }

    func module(_ id: ModuleID) -> (any UtilityModule)? {
        modules.first { type(of: $0).id == id }
    }

    func isEnabled(_ id: ModuleID) -> Bool {
        settings[AppSettings.enabledModules].contains(id.rawValue)
    }

    func isActive(_ id: ModuleID) -> Bool {
        active.contains(id)
    }

    func setEnabled(_ id: ModuleID, _ enabled: Bool) async {
        var ids = Set(settings[AppSettings.enabledModules])
        if enabled {
            ids.insert(id.rawValue)
        } else {
            ids.remove(id.rawValue)
        }
        settings[AppSettings.enabledModules] = ids.sorted()
        if enabled {
            await activate(id)
        } else {
            await deactivate(id)
        }
    }

    func activateEnabledModules() async {
        for module in modules where isEnabled(type(of: module).id) {
            await activate(type(of: module).id)
        }
    }

    func deactivateAll() async {
        for id in active {
            await deactivate(id)
        }
    }

    /// Status-menu items of the active modules.
    var menuItems: [NSMenuItem] {
        modules.filter { active.contains(type(of: $0).id) }.flatMap(\.menuItems)
    }

    /// CLI verbs of every module; a verb of an inactive module answers that the module is off.
    var ipcCommands: [IPCCommandHandler] {
        modules.flatMap { module in
            let id = type(of: module).id
            let name = module.displayName
            return module.ipcCommands.map { handler in
                IPCCommandHandler(verb: handler.verb, usage: handler.usage) { [weak self] request in
                    guard self?.isActive(id) == true else {
                        return .failure(request, "The \(name) is turned off. Turn it on in Settings → General.", status: 69)
                    }
                    return await handler.handle(request)
                }
            }
        }
    }

    private func activate(_ id: ModuleID) async {
        guard !active.contains(id), let module = module(id) else { return }
        let context = ModuleContext(services: services, settings: settings, log: Log.logger(id.rawValue))
        await module.activate(context: context)
        active.insert(id)
    }

    private func deactivate(_ id: ModuleID) async {
        guard active.contains(id), let module = module(id) else { return }
        await module.deactivate()
        active.remove(id)
    }
}
