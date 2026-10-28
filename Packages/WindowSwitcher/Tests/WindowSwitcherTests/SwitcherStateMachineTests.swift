import Hotkeys
import OrielCore
import Testing
@testable import WindowSwitcher

/// Hold/release, keep-open, cancel and Sticky Keys (PLAN §13.2), and the rest of the keyboard contract.
struct SwitcherStateMachineTests {
    private let tab = KeyCode.tab

    /// ⌥⇥ opened over `count` items in `columns` columns.
    private func opened(
        count: Int = 5,
        columns: Int = 5,
        shortcut: ShortcutSpec = .optionTab,
        stickyKeys: Bool = false
    ) -> SwitcherStateMachine {
        var machine = SwitcherStateMachine(shortcuts: [shortcut])
        machine.isStickyKeysOn = stickyKeys
        _ = machine.handle(.flagsChanged(shortcut.holdModifiers))
        _ = machine.handle(.keyDown(keyCode: shortcut.nextKey, modifiers: shortcut.holdModifiers))
        _ = machine.setItems(count: count, columns: columns)
        return machine
    }

    @Test func holdingTheModifierAndPressingTabOpensAndReleasingCommits() {
        var machine = SwitcherStateMachine()
        #expect(machine.handle(.flagsChanged(.option)) == .pass)
        #expect(machine.phase == .armed)
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option)) == .consume([.show(shortcutIndex: 0)]))
        // The second item is the window used before the current one.
        #expect(machine.setItems(count: 5, columns: 5) == [.select(1)])
        #expect(machine.handle(.keyUp(keyCode: tab, modifiers: .option)) == .consume)
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option)) == .consume([.select(2)]))
        #expect(machine.handle(.flagsChanged([])) == .pass([.commit(index: 2)]))
        #expect(machine.phase == .committing)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiA, modifiers: [])) == .pass)
        #expect(machine.phase == .idle)
    }

    @Test func aQuickPressAndReleaseSwitchesToThePreviousWindow() {
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: tab, modifiers: .option))
        _ = machine.setItems(count: 3, columns: 3)
        #expect(machine.handle(.flagsChanged([])).effects == [.commit(index: 1)])
    }

    @Test func theReverseModifierOpensAtTheEndAndStepsBack() {
        var machine = SwitcherStateMachine()
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: [.option, .shift])) == .consume([.show(shortcutIndex: 0)]))
        #expect(machine.setItems(count: 5, columns: 5) == [.select(4)])
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: [.option, .shift])).effects == [.select(3)])
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option)).effects == [.select(4)])
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option)).effects == [.select(0)])
    }

    @Test func releasingWithKeepOpenLeavesTheSwitcherOpenUntilReturn() {
        var keepOpen = ShortcutSpec.optionTab
        keepOpen.releaseBehavior = .keepOpen
        var machine = opened(shortcut: keepOpen)
        #expect(machine.handle(.flagsChanged([])) == .pass)
        #expect(machine.isOpen)
        // Without the modifier, Tab and Shift-Tab still step.
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: [])).effects == [.select(2)])
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .shift)).effects == [.select(1)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.returnKey, modifiers: [])) == .consume([.commit(index: 1)]))
    }

    @Test func escapeCancelsAndItsKeyUpIsSwallowedToo() {
        var machine = opened()
        #expect(machine.handle(.keyDown(keyCode: KeyCode.escape, modifiers: .option)) == .consume([.cancel]))
        #expect(machine.phase == .cancelled)
        #expect(machine.handle(.keyUp(keyCode: KeyCode.escape, modifiers: .option)) == .consume)
        #expect(machine.handle(.keyUp(keyCode: KeyCode.escape, modifiers: [])) == .pass)
        #expect(machine.handle(.flagsChanged([])) == .pass)
        #expect(machine.phase == .idle)
    }

    @Test func stickyKeysForcesKeepOpenAndSpaceCommits() {
        var machine = opened(stickyKeys: true)
        // The latched ⌥ is released right after Tab; with Sticky Keys that must not switch.
        #expect(machine.handle(.flagsChanged([])) == .pass)
        #expect(machine.isOpen)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.rightArrow, modifiers: [])).effects == [.select(2)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.space, modifiers: [], characters: " ")) == .consume([.commit(index: 2)]))
    }

    @Test func typingSearchesAndDeleteAndEscapeEditTheSearch() {
        var machine = opened(stickyKeys: true)
        _ = machine.handle(.flagsChanged([]))
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiS, modifiers: [], characters: "s")).effects == [.search("s")])
        #expect(machine.setItems(count: 2, columns: 2, selecting: 0) == [.select(0)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiA, modifiers: [], characters: "a")).effects == [.search("sa")])
        // While searching, Space and digits are text.
        #expect(machine.handle(.keyDown(keyCode: KeyCode.space, modifiers: [], characters: " ")).effects == [.search("sa ")])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansi2, modifiers: [], characters: "2")).effects == [.search("sa 2")])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.delete, modifiers: [])).effects == [.search("sa ")])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.escape, modifiers: [])).effects == [.search("")])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.escape, modifiers: [])).effects == [.cancel])
    }

    @Test func modifiedLettersActOnTheSelectedWindow() {
        var machine = opened(count: 3, columns: 3)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiW, modifiers: .option)).effects == [.act(.close, index: 1)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiW, modifiers: .option, isRepeat: true)).effects == [])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiM, modifiers: .option)).effects == [.act(.minimize, index: 1)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiF, modifiers: .option)).effects == [.act(.toggleFullScreen, index: 1)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: .option)).effects == [.quitApp(index: 1)])
        // Unassigned letters with a modifier are swallowed, not typed.
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiT, modifiers: .option, characters: nil)) == .consume)
    }

    @Test func digitsJumpAndSwitch() {
        var machine = opened(count: 4, columns: 4)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansi3, modifiers: .option)).effects == [.select(2), .commit(index: 2)])
        var keepOpen = opened(count: 4, columns: 4, stickyKeys: true)
        #expect(keepOpen.handle(.keyDown(keyCode: KeyCode.ansi4, modifiers: [], characters: "4")).effects == [
            .select(3),
            .commit(index: 3),
        ])
        var tooFar = opened(count: 2, columns: 2)
        #expect(tooFar.handle(.keyDown(keyCode: KeyCode.ansi9, modifiers: .option)).effects == [])
    }

    @Test func arrowsMoveByItemAndByRow() {
        var machine = opened(count: 10, columns: 4)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.downArrow, modifiers: .option)).effects == [.select(5)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.downArrow, modifiers: .option)).effects == [.select(9)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.downArrow, modifiers: .option)).effects == [])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.upArrow, modifiers: .option)).effects == [.select(5)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.leftArrow, modifiers: .option)).effects == [.select(4)])
        #expect(machine.setItems(count: 10, columns: 4, selecting: 9) == [.select(9)])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.rightArrow, modifiers: .option)).effects == [.select(0)])
    }

    @Test func otherKeysPassWhileClosedAndModifiersMustMatchExactly() {
        var machine = SwitcherStateMachine()
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiA, modifiers: .command)) == .pass)
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .command)) == .pass)
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: [.option, .command])) == .pass)
        #expect(machine.handle(.keyUp(keyCode: tab, modifiers: [])) == .pass)
        // Holding the trigger through a commit must not reopen on the auto-repeat.
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option, isRepeat: true)) == .pass)
        #expect(!machine.isOpen)
    }

    @Test func modifierChangesAreNeverConsumed() {
        var machine = opened()
        #expect(machine.handle(.flagsChanged([.option, .shift])).decision == .pass)
        #expect(machine.isOpen)
        #expect(machine.handle(.flagsChanged([])).decision == .pass)
    }

    @Test func aSuppressedFrontAppKeepsItsShortcuts() {
        var machine = SwitcherStateMachine()
        machine.isSuppressed = true
        #expect(machine.handle(.flagsChanged(.option)) == .pass)
        #expect(machine.phase == .idle)
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .option)) == .pass)
    }

    @Test func eachShortcutOpensItself() {
        let second = ShortcutSpec(holdModifiers: .option, nextKey: KeyCode.grave, filter: WindowFilter(apps: .active))
        var disabled = ShortcutSpec(holdModifiers: .control, nextKey: tab)
        disabled.isEnabled = false
        var machine = SwitcherStateMachine(shortcuts: [.optionTab, second, disabled])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.grave, modifiers: .option)).effects == [.show(shortcutIndex: 1)])
        _ = machine.setItems(count: 3, columns: 3)
        // Inside a session, the session's next key steps and Tab still works.
        #expect(machine.handle(.keyDown(keyCode: KeyCode.grave, modifiers: .option)).effects == [.select(2)])
        _ = machine.handle(.flagsChanged([]))
        #expect(machine.handle(.keyDown(keyCode: tab, modifiers: .control)) == .pass)
    }

    @Test func committingWithNothingToShowCancels() {
        var machine = opened(count: 0, columns: 1)
        #expect(machine.handle(.flagsChanged([])).effects == [.cancel])
    }

    @Test func hoverSelectsAndAClickCommits() {
        var machine = opened(count: 4, columns: 4)
        #expect(machine.select(3) == [.select(3)])
        #expect(machine.select(3) == [])
        #expect(machine.select(7) == [])
        #expect(machine.commit(at: 0) == [.commit(index: 0)])
        #expect(machine.cancel() == [])
    }

    @Test func theMenuItemOpensInKeepOpenMode() {
        var machine = SwitcherStateMachine()
        #expect(machine.open(shortcutIndex: 0) == [.show(shortcutIndex: 0)])
        #expect(machine.open(shortcutIndex: 0) == [])
        _ = machine.setItems(count: 3, columns: 3)
        #expect(machine.handle(.flagsChanged([])) == .pass)
        #expect(machine.isOpen)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.keypadEnterForTests, modifiers: [])).effects == [.commit(index: 1)])
        var invalid = SwitcherStateMachine()
        #expect(invalid.open(shortcutIndex: 4) == [])
    }

    @Test func aSwipeOpensStepsAndCommitsOnLift() {
        var machine = SwitcherStateMachine()
        #expect(machine.handle(.gesture(.began(.forward))) == .pass([.show(shortcutIndex: 0)]))
        _ = machine.setItems(count: 4, columns: 4)
        #expect(machine.handle(.gesture(.step(.forward))).effects == [.select(2)])
        #expect(machine.handle(.gesture(.step(.backward))).effects == [.select(1)])
        // Modifier changes do not end a swipe session.
        #expect(machine.handle(.flagsChanged([])).effects == [])
        #expect(machine.handle(.gesture(.ended)) == .pass([.commit(index: 1)]))
        _ = machine.handle(.gesture(.began(.backward)))
        _ = machine.setItems(count: 4, columns: 4)
        #expect(machine.selection == 3)
        #expect(machine.handle(.gesture(.cancelled)).effects == [.cancel])
    }

    @Test func aSwipeDuringAKeyboardSessionMovesTheSelection() {
        var machine = opened(count: 4, columns: 4)
        #expect(machine.handle(.gesture(.began(.forward))).effects == [.select(2)])
        #expect(machine.handle(.gesture(.ended)).effects == [])
        #expect(machine.isOpen)
    }
}

private extension KeyCode {
    static let keypadEnterForTests: UInt16 = 76
}
