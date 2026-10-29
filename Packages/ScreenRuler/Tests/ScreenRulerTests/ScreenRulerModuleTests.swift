import OrielCore
@testable import ScreenRuler
import Testing

@MainActor
struct ScreenRulerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ScreenRulerModule.id == .screenRuler)
        #expect(ScreenRulerModule().settingsSymbol == "ruler")
    }

    /// Screen Recording makes Dimensions find edges, but the ruler works without it, so it is not a requirement.
    @Test func itNeedsNoPermission() {
        #expect(ScreenRulerModule().requiredPermissions.isEmpty)
    }

    @Test func itsCommandIsTheOneAskedFor() throws {
        let command = try #require(ScreenRulerModule().commands.first)
        #expect(ScreenRulerModule().commands.count == 1)
        #expect(command.id == "openScreenRuler")
        #expect(command.title == "Screen Ruler")
        #expect(command.symbol == "ruler")
        #expect(command.group == .tools)
        #expect(command.defaultShortcut == KeyCombo(keyCode: KeyCode.ansiM, modifiers: [.control, .shift]))
        #expect(command.defaultShortcut?.description == "⌃⇧M")
        #expect(command.route == "ruler")
    }
}
