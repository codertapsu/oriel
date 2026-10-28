import AppKit
import Hotkeys
import OrielCore
import Testing

/// PLAN §13.2: the recorder refuses reserved combinations and flags conflicts with other Oriel shortcuts.
struct ShortcutRecorderTests {
    private let controlShiftT = KeyCombo(keyCode: KeyCode.ansiT, modifiers: [.control, .shift])

    private func decide(
        _ keyCode: UInt16,
        _ modifiers: KeyCombo.Modifiers,
        allowed: Set<KeyCombo> = [],
        inUse: [KeyCombo: String] = [:]
    ) -> RecorderDecision {
        RecorderDecision(keyCode: keyCode, modifiers: modifiers, allowed: allowed, inUse: inUse)
    }

    @Test func plainEscCancelsAndPlainDeleteClears() {
        #expect(decide(KeyCode.escape, []) == .cancel)
        #expect(decide(KeyCode.delete, []) == .clear)
        #expect(decide(KeyCode.forwardDelete, []) == .clear)
    }

    @Test func escAndDeleteWithModifiersAreOrdinaryCombinations() {
        let controlOptionEsc = KeyCombo(keyCode: KeyCode.escape, modifiers: [.control, .option])
        let controlShiftDelete = KeyCombo(keyCode: KeyCode.delete, modifiers: [.control, .shift])
        #expect(decide(KeyCode.escape, [.control, .option]) == .accept(controlOptionEsc, conflict: nil))
        #expect(decide(KeyCode.delete, [.control, .shift]) == .accept(controlShiftDelete, conflict: nil))
    }

    @Test(arguments: [
        KeyCombo(keyCode: KeyCode.ansiQ, modifiers: .command),
        KeyCombo(keyCode: KeyCode.tab, modifiers: .command),
        KeyCombo(keyCode: KeyCode.ansiA, modifiers: []),
    ])
    func reservedCombinationsAreRefusedWithAReason(_ combo: KeyCombo) {
        guard case let .refuse(reason) = decide(combo.keyCode, combo.modifiers) else {
            Issue.record("\(combo) was not refused")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test func anAllowedReservedCombinationIsAccepted() {
        let commandTab = ReservedShortcuts.commandTab
        #expect(decide(KeyCode.tab, .command, allowed: [commandTab]) == .accept(commandTab, conflict: nil))
    }

    @Test func aCombinationInUseIsAcceptedAndFlagged() {
        let decision = decide(KeyCode.ansiT, [.control, .shift], inUse: [controlShiftT: "Translate Area"])
        #expect(decision == .accept(controlShiftT, conflict: "Translate Area"))
        #expect(decide(KeyCode.ansi8, [.control, .shift], inUse: [controlShiftT: "Translate Area"])
            == .accept(KeyCombo(keyCode: KeyCode.ansi8, modifiers: [.control, .shift]), conflict: nil))
    }

    /// The view applies the decision: a typed combination in use becomes the shortcut and is flagged.
    @MainActor
    @Test func theViewRecordsAndFlagsAConflict() throws {
        let view = ShortcutRecorderView(frame: CGRect(x: 0, y: 0, width: 150, height: 24))
        view.inUse = [controlShiftT: "Translate Area"]
        var changes: [KeyCombo?] = []
        view.onChange = { changes.append($0) }
        let click = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        view.mouseDown(with: click)
        let key = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.control, .shift], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{14}", charactersIgnoringModifiers: "t", isARepeat: false, keyCode: KeyCode.ansiT
        ))
        view.keyDown(with: key)
        #expect(changes == [controlShiftT])
        #expect(view.combo == controlShiftT)
        #expect(view.toolTip == "Also used for Translate Area.")
    }
}
