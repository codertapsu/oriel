import OrielCore
import PrivateAPIs
import Testing
@testable import WindowSwitcher

/// Cmd-Tab hot key discovery from fake `SymbolicHotKey` lists (PLAN §7.1.4): ids are found by enumeration,
/// never assumed. The real Cmd-Tab is never touched.
struct CommandTabTakeoverTests {
    static let commandTab = ShortcutSpec(holdModifiers: .command, nextKey: KeyCode.tab, reverseModifier: .shift)

    @Test func commandTabFindsBothSystemSwitcherKeys() {
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: [Self.commandTab]) == [1, 2])
    }

    @Test func idsComeFromTheListNotFromAssumptions() {
        // Another macOS could number them differently.
        let renumbered = [
            SymbolicHotKey(id: 7, virtualKeyCode: 48, modifiers: 0x100000, isEnabled: true),
            SymbolicHotKey(id: 9, virtualKeyCode: 48, modifiers: 0x120000, isEnabled: true),
            SymbolicHotKey(id: 1, virtualKeyCode: 49, modifiers: 0x100000, isEnabled: true),
        ]
        #expect(CommandTabTakeover.hotKeyIDs(in: renumbered, for: [Self.commandTab]) == [7, 9])
    }

    @Test func otherShortcutsTakeNothingOver() {
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: [.optionTab]) == [])
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: []) == [])
        var disabled = Self.commandTab
        disabled.isEnabled = false
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: [disabled]) == [])
    }

    @Test func aCommandTabWithoutReverseStillTakesTheSystemReverse() {
        let forwardOnly = ShortcutSpec(holdModifiers: .command, nextKey: KeyCode.tab, reverseModifier: nil)
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: [forwardOnly]) == [1, 2])
        #expect(CommandTabTakeover.usesCommandTab([forwardOnly]))
        #expect(!CommandTabTakeover.usesCommandTab([.optionTab]))
    }

    @Test func anyCollidingSystemKeyIsFound() {
        let controlSpace = ShortcutSpec(holdModifiers: .control, nextKey: KeyCode.space, reverseModifier: nil)
        #expect(CommandTabTakeover.hotKeyIDs(in: FakeHotKeys.macOS27, for: [controlSpace]) == [60])
    }

    @Test func modifierBitsOutsideTheFourModifiersAreIgnored() {
        let withFunction = [SymbolicHotKey(id: 1, virtualKeyCode: 48, modifiers: 0x100000 | 0x800000, isEnabled: true)]
        #expect(CommandTabTakeover.hotKeyIDs(in: withFunction, for: [Self.commandTab]) == [1])
    }

    @Test func keysTheUserTurnedOffStayTheirs() {
        var keys = FakeHotKeys.macOS27
        keys[0] = SymbolicHotKey(id: 1, virtualKeyCode: 48, modifiers: 0x100000, isEnabled: false)
        #expect(CommandTabTakeover.hotKeyIDs(in: keys, for: [Self.commandTab]) == [2])
        // …unless we turned it off ourselves.
        #expect(CommandTabTakeover.hotKeyIDs(in: keys, for: [Self.commandTab], disabledByUs: [1]) == [1, 2])
    }
}
