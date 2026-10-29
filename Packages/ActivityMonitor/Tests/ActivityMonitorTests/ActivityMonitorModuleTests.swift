@testable import ActivityMonitor
import OrielCore
import Testing

@MainActor
struct ActivityMonitorModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ActivityMonitorModule.id == .activityMonitor)
        #expect(ActivityMonitorModule().displayName == "Activity Monitor")
        #expect(ActivityMonitorModule().settingsSymbol == "gauge.with.dots.needle.67percent")
    }

    /// The id, group and route the brief assigns, and no default shortcut, so it takes no key from other apps.
    @Test func itOpensFromTheToolsMenuAndItsURL() throws {
        let command = try #require(ActivityMonitorModule().commands.first)
        #expect(command.id == "openActivityMonitor")
        #expect(command.title == "Activity Monitor")
        #expect(command.group == .tools)
        #expect(command.route == "activity")
        #expect(command.defaultShortcut == nil)
        #expect(command.shortcutKey.name == "shortcuts.openActivityMonitor")
        #expect(command.showsInMenu)
    }

    @Test func itAnswersTop() throws {
        let handler = try #require(ActivityMonitorModule().ipcCommands.first)
        #expect(handler.verb == "top")
        #expect(handler.usage == "top [--sort cpu|memory|disk|network] [--limit <n>] [--json]")
        #expect(ActivityMonitorModule().settingsPane != nil)
    }

    @Test func openingWhileOffDoesNothing() {
        let module = ActivityMonitorModule()
        module.openWindow()
        #expect(!module.isWindowOpen)
    }

    @Test(arguments: [
        ["sort": "speed"], ["limit": "0"], ["limit": "1001"], ["limit": "lots"],
    ])
    func badTopOptionsAreUsageErrors(_ options: [String: String]) async {
        let response = await TopCommand.run(IPCRequest(verb: "top", options: options))
        #expect(response.status == 64)
        #expect(response.error?.isEmpty == false)
    }
}
