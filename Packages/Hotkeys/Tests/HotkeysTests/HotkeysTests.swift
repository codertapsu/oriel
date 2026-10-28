import AppKit
import CoreGraphics
import Hotkeys
import OrielCore
import OrielTestSupport
import Testing

struct ModifierMappingTests {
    @Test(arguments: [KeyCombo.Modifiers.command, .option, .control, .shift, [.command, .shift], [.control, .option, .shift, .command]])
    func modifiersRoundTripThroughEveryFlagType(_ modifiers: KeyCombo.Modifiers) {
        #expect(KeyCombo.Modifiers(cgFlags: modifiers.cgFlags) == modifiers)
        #expect(KeyCombo.Modifiers(eventFlags: modifiers.eventFlags) == modifiers)
    }

    @Test func carbonFlagsMatchEventsDotH() {
        #expect(KeyCombo.Modifiers.command.carbonFlags == 0x100)
        #expect(KeyCombo.Modifiers.shift.carbonFlags == 0x200)
        #expect(KeyCombo.Modifiers.option.carbonFlags == 0x800)
        #expect(KeyCombo.Modifiers.control.carbonFlags == 0x1000)
    }

    @Test func cgFlagsIgnoreNonModifierBits() {
        let flags: CGEventFlags = [.maskCommand, .maskNumericPad, .maskSecondaryFn]
        #expect(KeyCombo.Modifiers(cgFlags: flags) == .command)
    }
}

struct ReservedShortcutTests {
    @Test func refusesSystemCombosUnlessAllowed() {
        #expect(ReservedShortcuts.reason(for: KeyCombo(keyCode: KeyCode.ansiQ, modifiers: .command)) != nil)
        #expect(ReservedShortcuts.reason(for: ReservedShortcuts.commandTab) != nil)
        #expect(ReservedShortcuts.reason(for: ReservedShortcuts.commandTab, allowing: [ReservedShortcuts.commandTab]) == nil)
        #expect(ReservedShortcuts.reason(for: KeyCombo(keyCode: KeyCode.ansi4, modifiers: [.control, .shift])) == nil)
    }

    @Test func plainKeysNeedAModifierButFunctionKeysDoNot() {
        #expect(ReservedShortcuts.reason(for: KeyCombo(keyCode: KeyCode.ansiA, modifiers: [])) != nil)
        #expect(ReservedShortcuts.reason(for: KeyCombo(keyCode: 122, modifiers: [])) == nil) // F1
    }
}

@MainActor
struct CarbonHotkeyEngineTests {
    @Test func registersReplacesAndUnregisters() throws {
        let engine = CarbonHotkeyEngine()
        let first = KeyCombo(keyCode: KeyCode.ansi9, modifiers: [.control, .option, .shift, .command])
        let second = KeyCombo(keyCode: KeyCode.ansi8, modifiers: [.control, .option, .shift, .command])
        try engine.register(first, name: "test") {}
        #expect(engine.registered == ["test": first])
        try engine.register(second, name: "test") {}
        #expect(engine.registered == ["test": second])
        engine.unregisterAll()
        #expect(engine.registered.isEmpty)
    }
}

@MainActor
struct ShortcutRecorderViewTests {
    @Test func drawsWithoutAComboAndExposesAnAccessibleButton() {
        let view = ShortcutRecorderView(frame: CGRect(x: 0, y: 0, width: 150, height: 24))
        #expect(view.accessibilityRole() == .button)
        #expect(view.accessibilityLabel() == "Record shortcut")
        view.combo = KeyCombo(keyCode: KeyCode.ansiT, modifiers: [.control, .shift])
        #expect(view.accessibilityLabel() == "Shortcut ⌃⇧T")
    }
}

/// Creating an active tap needs Accessibility.
@MainActor
@Test(.requiresTCC)
func eventTapStartsAndStops() throws {
    let engine = EventTapEngine(options: [.keyboard])
    engine.handler = { _ in .pass }
    try engine.start()
    #expect(engine.isRunning)
    engine.stop()
    #expect(!engine.isRunning)
}
