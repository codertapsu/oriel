import OrielCore
import Testing

struct ToolCommandTests {
    /// The key a command's shortcut is kept under is derived from its id, which is how a shortcut set while the action
    /// was still in the app's own table (`shortcuts.showClipboardHistory`) survives the move to a tool's command.
    @Test func theShortcutIsKeptUnderTheCommandsID() {
        let combo = KeyCombo(keyCode: KeyCode.ansiV, modifiers: .option)
        let command = ToolCommand(
            id: "showClipboardHistory",
            title: "Clipboard History",
            symbol: "list.clipboard",
            group: .library,
            defaultShortcut: combo
        ) {}
        #expect(command.shortcutKey.name == "shortcuts.showClipboardHistory")
        #expect(command.shortcutKey.defaultValue == combo)
        #expect(command.showsInMenu)
        #expect(command.route == nil)
    }

    @Test func aCommandWithoutADefaultHasNoShortcut() {
        let command = ToolCommand(id: "openDiskAnalyzer", title: "Disk Space Analyzer", symbol: "internaldrive", group: .tools) {}
        #expect(command.shortcutKey.defaultValue == nil)
    }
}
