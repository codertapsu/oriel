import AppKit
@testable import Editor
import OrielCore
import Testing

/// The keyboard map of PLAN §7.5.
struct ShortcutTests {
    private func command(_ characters: String, keyCode: UInt16 = 0, _ modifiers: KeyCombo.Modifiers = []) -> EditorCommand? {
        EditorShortcuts.command(characters: characters, keyCode: keyCode, modifiers: modifiers)
    }

    @Test(arguments: [
        ("v", EditorTool.select), ("a", .arrow), ("l", .line), ("r", .rectangle), ("o", .ellipse), ("p", .pen),
        ("h", .highlighter), ("t", .text), ("n", .counter), ("b", .blur), ("x", .pixelate), ("s", .spotlight), ("c", .crop),
    ])
    func singleLettersPickTools(_ letter: String, _ tool: EditorTool) {
        #expect(command(letter) == .tool(tool))
        #expect(command(letter.uppercased(), [.shift]) == nil)
        #expect(command(letter, [.option]) == nil)
    }

    @Test func everyToolHasAUniqueShortcut() {
        #expect(Set(EditorTool.allCases.map(\.shortcut)).count == EditorTool.allCases.count)
        for tool in EditorTool.allCases {
            #expect(EditorTool.forShortcut(tool.shortcut) == tool)
        }
    }

    @Test func editingKeys() {
        #expect(command("\u{7F}", keyCode: KeyCode.delete) == .delete)
        #expect(command("\u{F728}", keyCode: KeyCode.forwardDelete) == .delete)
        #expect(command("\u{1B}", keyCode: KeyCode.escape) == .cancel)
        #expect(command("\r", keyCode: KeyCode.returnKey) == .confirm)
        #expect(command("\u{F702}", keyCode: KeyCode.leftArrow) == .nudge(dx: -1, dy: 0))
        #expect(command("\u{F701}", keyCode: KeyCode.downArrow, [.shift]) == .nudge(dx: 0, dy: 10))
    }

    @Test func commandShortcuts() {
        #expect(command("z", [.command]) == .undo)
        #expect(command("Z", [.command, .shift]) == .redo)
        #expect(command("c", [.command]) == .copy)
        #expect(command("s", [.command]) == .save)
        #expect(command("e", [.command]) == .export)
        #expect(command("y", [.command]) == .quickLook)
        #expect(command("a", [.command]) == .selectAll)
        #expect(command("w", [.command]) == .close)
        #expect(command("=", [.command]) == .zoomIn)
        #expect(command("+", [.command, .shift]) == .zoomIn)
        #expect(command("-", [.command]) == .zoomOut)
        #expect(command("0", [.command]) == .actualSize)
        #expect(command("9", [.command]) == .zoomToFit)
        // Not ours: paste, ⌥⌘ and ⌃⌘ combinations, ⇧⌘C.
        #expect(command("v", [.command]) == nil)
        #expect(command("z", [.command, .option]) == nil)
        #expect(command("c", [.command, .control]) == nil)
        #expect(command("C", [.command, .shift]) == nil)
    }

    @Test @MainActor func appKitModifierFlagsMapToKeyComboModifiers() {
        #expect(KeyCombo.Modifiers(modifierFlags: [.command, .shift, .numericPad]) == [.command, .shift])
        #expect(KeyCombo.Modifiers(modifierFlags: [.control, .option]) == [.control, .option])
    }
}
