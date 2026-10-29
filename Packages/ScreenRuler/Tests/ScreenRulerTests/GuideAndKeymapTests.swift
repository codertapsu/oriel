import CoreGraphics
import OrielCore
@testable import ScreenRuler
import Testing

struct GuideSetTests {
    private let display = RulerDisplay(id: 7, frame: CGRect(x: 100, y: 0, width: 1000, height: 800), scale: 2)

    @Test func guidesMeasureTheGapsBetweenThem() throws {
        var guides = GuideSet()
        guides.add(.vertical, at: 400, on: display)
        let middle = guides.add(.vertical, at: 250, on: display)
        guides.add(.vertical, at: 700, on: display)
        guides.add(.horizontal, at: 120, on: display)
        #expect(guides.guides(.vertical, on: 7).map(\.position) == [250, 400, 700])
        #expect(guides.gaps(.vertical, on: 7) == [250 ... 400, 400 ... 700])
        #expect(guides.gaps(.horizontal, on: 7).isEmpty)
        #expect(guides.bounds(around: 500, .vertical, on: display) == 400 ... 700)
        #expect(guides.bounds(around: 150, .vertical, on: display) == 100 ... 250, "the display's edge where there is no guide")
        #expect(guides.bounds(around: 50, .horizontal, on: display) == 0 ... 120)

        #expect(guides.guide(near: CGPoint(x: 252, y: 10), on: 7, tolerance: 4)?.id == middle)
        #expect(guides.guide(near: CGPoint(x: 260, y: 10), on: 7, tolerance: 4) == nil)
        #expect(guides.guide(near: CGPoint(x: 252, y: 10), on: 8, tolerance: 4) == nil, "another display's guides")

        guides.move(middle, to: 5000, on: display)
        #expect(try #require(guides.guide(middle)).position == 1100, "kept on the display")
        guides.remove(middle)
        #expect(guides.guides(.vertical, on: 7).count == 2)
        guides.removeAll()
        #expect(guides.guides.isEmpty)
    }
}

/// A key press, as AppKit reports it, and what it should mean.
struct KeyPress: Sendable, CustomTestStringConvertible {
    let code: UInt16
    let modifiers: KeyCombo.Modifiers
    let characters: String
    let meaning: RulerKey

    init(_ code: UInt16, _ modifiers: KeyCombo.Modifiers, _ characters: String, _ meaning: RulerKey) {
        self.code = code
        self.modifiers = modifiers
        self.characters = characters
        self.meaning = meaning
    }

    var testDescription: String {
        "\(modifiers.symbols)\(characters.debugDescription) (\(code)) → \(meaning)"
    }
}

struct RulerKeymapTests {
    static let table: [KeyPress] = [
        KeyPress(KeyCode.tab, [], "\t", .nextMode),
        KeyPress(KeyCode.tab, .shift, "\t", .previousMode),
        KeyPress(KeyCode.escape, [], "", .exit),
        KeyPress(KeyCode.returnKey, [], "\r", .confirm),
        KeyPress(RulerKeymap.keypadEnter, [], "\u{3}", .confirm),
        KeyPress(KeyCode.space, [], " ", .flipGuide),
        KeyPress(KeyCode.delete, [], "", .delete),
        KeyPress(KeyCode.delete, .command, "", .deleteAll),
        KeyPress(KeyCode.leftArrow, [], "", .arrow(dx: -1, dy: 0, resizes: false)),
        KeyPress(KeyCode.downArrow, .shift, "", .arrow(dx: 0, dy: 10, resizes: false)),
        KeyPress(KeyCode.upArrow, .option, "", .arrow(dx: 0, dy: -1, resizes: true)),
        KeyPress(KeyCode.ansiC, .command, "c", .copy),
        KeyPress(33, [], "[", .tolerance(delta: -1)),
        KeyPress(30, [], "]", .tolerance(delta: 1)),
        KeyPress(33, .shift, "{", .tolerance(delta: -5)),
        KeyPress(30, .shift, "}", .tolerance(delta: 5)),
        KeyPress(KeyCode.ansiU, [], "u", .toggleUnit),
        KeyPress(KeyCode.ansiU, .shift, "U", .toggleUnit),
        KeyPress(4, [], "h", .guideOrientation(.horizontal)),
        KeyPress(9, [], "v", .guideOrientation(.vertical)),
        KeyPress(KeyCode.ansi1, [], "1", .mode(.measureArea)),
        KeyPress(KeyCode.ansi3, [], "3", .mode(.guides)),
    ]

    @Test(arguments: table)
    func keysMeanWhatTheHintBarSays(_ press: KeyPress) {
        #expect(RulerKeymap.key(code: press.code, modifiers: press.modifiers, characters: press.characters) == press.meaning)
    }

    @Test func otherKeysMeanNothing() {
        #expect(RulerKeymap.key(code: KeyCode.ansiQ, modifiers: [], characters: "q") == nil)
        #expect(RulerKeymap.key(code: KeyCode.ansiV, modifiers: .command, characters: "v") == nil)
        #expect(RulerKeymap.key(code: KeyCode.ansi9, modifiers: [], characters: "9") == nil)
    }

    /// On a layout where the key in the ANSI `[` position types something else, the character decides.
    @Test func bracketsAreReadFromWhatTheyType() {
        #expect(RulerKeymap.key(code: 37, modifiers: [], characters: "[") == .tolerance(delta: -1))
        #expect(RulerKeymap.key(code: 33, modifiers: [], characters: "ü") == nil)
    }
}
