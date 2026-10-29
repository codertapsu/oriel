@testable import ClipboardHistory
import OrielCore
import Testing

@MainActor
struct ClipboardHistoryModuleTests {
    /// ⌥V, as asked for. The command keeps the id the shortcut had as an app action, so a shortcut the user set before
    /// keeps working, and `oriel://clipboard` too; it is registered only while Clipboard History is on.
    @Test func thePanelOpensWithOptionV() throws {
        let command = try #require(ClipboardHistoryModule().commands.first)
        #expect(command.id == "showClipboardHistory")
        #expect(command.shortcutKey.name == "shortcuts.showClipboardHistory")
        #expect(command.defaultShortcut == KeyCombo(keyCode: KeyCode.ansiV, modifiers: .option))
        #expect(command.defaultShortcut?.description == "⌥V")
        #expect(command.route == "clipboard")
        #expect(command.group == .library)
    }
}
