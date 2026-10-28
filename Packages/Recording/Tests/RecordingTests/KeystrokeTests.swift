import AppKit
import OrielCore
@testable import Recording
import Testing

struct KeystrokeTests {
    private func press(
        _ keyCode: UInt16,
        _ modifiers: KeyCombo.Modifiers = [],
        _ text: String? = nil,
        base: String? = nil
    ) -> KeystrokeFormatter.Press? {
        KeystrokeFormatter.press(keyCode: keyCode, modifiers: modifiers, characters: text, baseCharacters: base ?? text)
    }

    @Test func plainTypingIsText() {
        #expect(press(KeyCode.ansiA, [], "a") == .init(label: "a", isText: true))
        #expect(press(KeyCode.ansiA, .shift, "A", base: "a") == .init(label: "A", isText: true))
        #expect(press(KeyCode.space, [], " ") == .init(label: " ", isText: true))
    }

    @Test func shortcutsShowTheirModifiersInMenuOrder() {
        #expect(press(KeyCode.ansi4, [.command, .shift], "$", base: "4")?.label == "⇧⌘4")
        #expect(press(KeyCode.ansiS, .command, "s")?.label == "⌘S")
        #expect(press(KeyCode.ansiA, [.control, .option], "å", base: "a")?.label == "⌃⌥A")
        #expect(press(KeyCode.space, .command, " ")?.label == "⌘Space")
        #expect(press(KeyCode.ansiS, .command, "s")?.isText == false)
    }

    @Test func specialKeysShowTheirSymbols() {
        #expect(press(KeyCode.returnKey, [], "\r")?.label == "↩")
        #expect(press(KeyCode.escape, [], "\u{1B}")?.label == "⎋")
        #expect(press(KeyCode.tab, .shift, "\t")?.label == "⇧⇥")
        #expect(press(KeyCode.leftArrow, .option, "\u{F702}")?.label == "⌥←")
        #expect(press(KeystrokeFormatter.keypadEnter, [], "\u{3}")?.label == "⌅")
        #expect(press(122, [], "\u{F704}")?.label == "F1")
    }

    @Test func mapsAppKitModifiers() {
        let flags: NSEvent.ModifierFlags = [.command, .option, .capsLock, .function]
        #expect(KeystrokeFormatter.modifiers(from: flags) == [.command, .option])
        #expect(KeystrokeFormatter.modifiers(from: [.control, .shift]) == [.control, .shift])
    }

    @Test func recognizesPrintableText() {
        #expect(KeystrokeFormatter.isPrintable("é"))
        #expect(!KeystrokeFormatter.isPrintable(""))
        #expect(!KeystrokeFormatter.isPrintable("\u{7F}"))
        #expect(!KeystrokeFormatter.isPrintable("\u{F703}"))
    }

    @Test func typingAccumulatesAndShortcutsReplaceIt() {
        var line = KeystrokeLine()
        for character in "hello" {
            line.append(.init(label: String(character), isText: true))
        }
        #expect(line.displayText == "hello")
        line.append(.init(label: "⌘S", isText: false))
        #expect(line.displayText == "⌘S")
        line.append(.init(label: "x", isText: true))
        #expect(line.displayText == "x")
        line.append(.init(label: "↩", isText: false))
        line.append(.init(label: "↩", isText: false))
        #expect(line.displayText == "↩")
    }

    @Test func longTextScrollsOffTheFront() {
        var line = KeystrokeLine()
        for _ in 0 ..< 40 {
            line.append(.init(label: "a", isText: true))
        }
        line.append(.init(label: "b", isText: true))
        #expect(line.text.count == KeystrokeLine.maximumLength)
        #expect(line.text.hasSuffix("ab"))
    }

    @Test func aLoneSpaceIsVisible() {
        var line = KeystrokeLine()
        line.append(.init(label: " ", isText: true))
        #expect(line.displayText == "␣")
        line.reset()
        #expect(line.displayText.isEmpty)
    }
}
