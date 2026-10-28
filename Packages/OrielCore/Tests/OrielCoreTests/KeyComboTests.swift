import Foundation
import OrielCore
import Testing

struct KeyComboTests {
    @Test func descriptionUsesMenuOrderAndKeyNames() {
        #expect(KeyCombo(keyCode: KeyCode.ansi4, modifiers: [.shift, .control]).description == "⌃⇧4")
        #expect(KeyCombo(keyCode: KeyCode.tab, modifiers: [.command, .option]).description == "⌥⌘⇥")
        #expect(KeyCombo(keyCode: 999, modifiers: []).description == "key 999")
    }

    @Test func roundTripsThroughJSON() throws {
        let combo = KeyCombo(keyCode: KeyCode.ansiT, modifiers: [.control, .shift])
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: JSONEncoder().encode(combo))
        #expect(decoded == combo)
    }
}
