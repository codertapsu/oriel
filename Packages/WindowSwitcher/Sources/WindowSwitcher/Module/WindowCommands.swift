import Foundation
import OrielCore

/// The switcher's CLI verbs (PLAN §7.1.8): `windows.list`, `windows.focus`, `windows.close`,
/// `windows.minimize` and, in Debug builds, `debug.open-switcher`.
enum WindowCommands {
    static func handlers(for module: WindowSwitcherModule) -> [IPCCommandHandler] {
        var handlers = [
            IPCCommandHandler(
                verb: "windows.list",
                usage: "windows list [--json] [--space current|all] [--app <bundle-id>]"
            ) { [weak module] request in
                guard let module else { return notRunning(request) }
                return await list(request, module: module)
            },
            IPCCommandHandler(verb: "windows.focus", usage: "windows focus <window-id> | --title <substring>") { [weak module] request in
                guard let module else { return notRunning(request) }
                return await focus(request, module: module)
            },
            IPCCommandHandler(verb: "windows.close", usage: "windows close <window-id>") { [weak module] request in
                guard let module else { return notRunning(request) }
                return await act(.close, request, module: module)
            },
            IPCCommandHandler(verb: "windows.minimize", usage: "windows minimize <window-id>") { [weak module] request in
                guard let module else { return notRunning(request) }
                return await act(.minimize, request, module: module)
            },
        ]
        #if DEBUG
            // A UI-test hook, compiled out of Release builds (PLAN §14.3).
            handlers.append(openSwitcherHandler(for: module))
        #endif
        return handlers
    }

    private static func openSwitcherHandler(for module: WindowSwitcherModule) -> IPCCommandHandler {
        IPCCommandHandler(verb: "debug.open-switcher", usage: "debug open-switcher [--shortcut 1-9]") { [weak module] request in
            guard let module else { return notRunning(request) }
            return openSwitcher(request, module: module)
        }
    }

    static func list(_ request: IPCRequest, module: WindowSwitcherModule) async -> IPCResponse {
        let space = request.options["space"] ?? "all"
        guard space == "all" || space == "current" else {
            return .failure(request, "usage: oriel windows list [--json] [--space current|all] [--app <bundle-id>]", status: 64)
        }
        var windows = await module.windows(includeOtherSpaces: space == "all")
        if let app = request.options["app"] {
            guard app != "true" else { return .failure(request, "usage: --app needs a bundle ID", status: 64) }
            windows = windows.filter { $0.bundleID?.caseInsensitiveCompare(app) == .orderedSame }
        }
        guard request.flag("json") else { return .ok(request, WindowTable.render(windows)) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(windows), let json = String(data: data, encoding: .utf8) else {
            return .failure(request, "Could not encode the window list.")
        }
        return .ok(request, json)
    }

    static func focus(_ request: IPCRequest, module: WindowSwitcherModule) async -> IPCResponse {
        let windowID: UInt32
        if let title = request.options["title"] {
            guard title != "true", !title.isEmpty else { return .failure(
                request,
                "usage: oriel windows focus --title <substring>",
                status: 64
            ) }
            let windows = await module.windows(includeOtherSpaces: true)
            guard let match = windows.first(where: { $0.title.localizedCaseInsensitiveContains(title) }) else {
                return .failure(request, "No window title contains “\(title)”.")
            }
            windowID = match.id
        } else {
            guard let id = request.arguments.first.flatMap({ UInt32($0) }) else {
                return .failure(request, "usage: oriel windows focus <window-id> | --title <substring>", status: 64)
            }
            windowID = id
        }
        guard await module.focus(windowID: windowID) else {
            return .failure(request, "Could not focus window \(windowID).")
        }
        return .ok(request, String(windowID))
    }

    static func act(_ action: WindowAction, _ request: IPCRequest, module: WindowSwitcherModule) async -> IPCResponse {
        let verb = action == .close ? "close" : "minimize"
        guard let windowID = request.arguments.first.flatMap({ UInt32($0) }) else {
            return .failure(request, "usage: oriel windows \(verb) <window-id>", status: 64)
        }
        guard await module.perform(action, windowID: windowID) else {
            return .failure(request, "Could not \(verb) window \(windowID): it is gone, on a Space Oriel cannot reach, or it refuses.")
        }
        return .ok(request)
    }

    static func openSwitcher(_ request: IPCRequest, module: WindowSwitcherModule) -> IPCResponse {
        let number = request.options["shortcut"].map { Int($0) } ?? 1
        guard let number, (1 ... ShortcutSpec.maximumCount).contains(number) else {
            return .failure(request, "usage: oriel debug open-switcher [--shortcut 1-9]", status: 64)
        }
        guard module.isSwitcherRunning else { return notRunning(request) }
        module.show(shortcutIndex: number - 1)
        return .ok(request)
    }

    private static func notRunning(_ request: IPCRequest) -> IPCResponse {
        .failure(request, "The window switcher is not running.")
    }
}
