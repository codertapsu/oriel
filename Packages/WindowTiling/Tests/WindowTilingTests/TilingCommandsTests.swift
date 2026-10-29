import AppKit
import OrielCore
import Testing
@testable import WindowTiling

/// The commands' ids and Rectangle-like defaults, exactly as the plan assigns them, and how the menu shows them.
struct TilingCommandsTests {
    private static let controlOption: KeyCombo.Modifiers = [.control, .option]

    @Test(arguments: [
        ("tileLeftHalf", KeyCode.leftArrow, controlOption),
        ("tileRightHalf", KeyCode.rightArrow, controlOption),
        ("tileTopHalf", KeyCode.upArrow, controlOption),
        ("tileBottomHalf", KeyCode.downArrow, controlOption),
        ("tileTopLeft", KeyCode.ansiU, controlOption),
        ("tileTopRight", KeyCode.ansiI, controlOption),
        ("tileBottomLeft", KeyCode.ansiJ, controlOption),
        ("tileBottomRight", KeyCode.ansiK, controlOption),
        ("tileFirstThird", KeyCode.ansiD, controlOption),
        ("tileCenterThird", KeyCode.ansiF, controlOption),
        ("tileLastThird", KeyCode.ansiG, controlOption),
        ("tileFirstTwoThirds", KeyCode.ansiE, controlOption),
        ("tileLastTwoThirds", KeyCode.ansiT, controlOption),
        ("tileMaximize", KeyCode.returnKey, controlOption),
        ("tileMaximizeHeight", KeyCode.upArrow, controlOption.union(.shift)),
        ("tileCenter", KeyCode.ansiC, controlOption),
        ("tileRestore", KeyCode.delete, controlOption),
        ("tileNextDisplay", KeyCode.rightArrow, controlOption.union(.command)),
        ("tilePreviousDisplay", KeyCode.leftArrow, controlOption.union(.command)),
        ("tileSmaller", KeyCode.ansiMinus, controlOption),
        ("tileLarger", KeyCode.ansiEqual, controlOption),
    ])
    func everyCommandHasItsDefaultShortcut(_ id: String, _ key: UInt16, _ modifiers: KeyCombo.Modifiers) throws {
        let action = try #require(TilingAction.allCases.first { $0.commandID == id })
        #expect(action.defaultShortcut == KeyCombo(keyCode: key, modifiers: modifiers))
    }

    @Test func almostMaximizeHasNoDefaultShortcut() {
        #expect(TilingAction.almostMaximize.commandID == "tileAlmostMaximize")
        #expect(TilingAction.almostMaximize.defaultShortcut == nil)
    }

    @Test func idsAndShortcutsAreUniqueAndCommandsStayOutOfTheMenuList() {
        let actions = TilingAction.allCases
        #expect(actions.count == 22)
        #expect(Set(actions.map(\.commandID)).count == actions.count)
        #expect(actions.allSatisfy { $0.commandID.hasPrefix("tile") })
        let shortcuts = actions.compactMap(\.defaultShortcut)
        #expect(shortcuts.count == 21 && Set(shortcuts).count == 21)
        for action in actions {
            let command = action.command {}
            #expect(command.id == action.commandID && command.title == action.title)
            #expect(command.group == .tools && !command.showsInMenu && command.route == nil)
            #expect(command.shortcutKey.name == "shortcuts.\(action.commandID)")
            #expect(action.shortcutKey == command.shortcutKey)
        }
    }

    @Test func everySymbolExists() {
        for action in TilingAction.allCases {
            #expect(NSImage(systemSymbolName: action.symbol, accessibilityDescription: nil) != nil, "\(action.symbol)")
        }
    }

    @Test func theMenuAndTheSettingsListEveryActionOnce() {
        let listed = TilingAction.menuSections.flatMap(\.self)
        #expect(listed.count == TilingAction.allCases.count)
        #expect(Set(listed) == Set(TilingAction.allCases))
        let rows = TilingSettingsView.shortcutRows.flatMap(\.self)
        #expect(rows.count == TilingAction.allCases.count && Set(rows) == Set(TilingAction.allCases))
    }

    @Test func onlyHalvesCycleAndOnlyFixedLayoutsTravelBetweenDisplays() {
        #expect(TilingAction.allCases.filter(\.cyclesSizes) == [.leftHalf, .rightHalf, .topHalf, .bottomHalf])
        #expect(!TilingAction.center.isFixedLayout && !TilingAction.maximizeHeight.isFixedLayout)
        #expect(TilingAction.almostMaximize.isFixedLayout && TilingAction.lastTwoThirds.isFixedLayout)
    }

    // MARK: Menu key equivalents

    @Test(arguments: [
        (KeyCode.leftArrow, String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)),
        (KeyCode.upArrow, String(utf16CodeUnits: [unichar(NSUpArrowFunctionKey)], count: 1)),
        (KeyCode.returnKey, "\r"),
        (KeyCode.delete, "\u{8}"),
        (KeyCode.ansiU, "u"),
        (KeyCode.ansiMinus, "-"),
        (KeyCode.ansiEqual, "="),
        (KeyCode.ansi1, "1"),
        (UInt16(122), String(utf16CodeUnits: [unichar(NSF1FunctionKey)], count: 1)),
    ])
    func keysBecomeMenuKeyEquivalents(_ keyCode: UInt16, _ expected: String) {
        #expect(MenuKeyEquivalent.character(for: keyCode) == expected)
    }

    @Test func modifiersBecomeMenuModifierFlags() throws {
        let combo = try #require(TilingAction.nextDisplay.defaultShortcut)
        let equivalent = try #require(MenuKeyEquivalent.make(for: combo))
        #expect(equivalent.modifiers == [.control, .option, .command])
        #expect(MenuKeyEquivalent.flags(for: [.shift]) == [.shift])
        // A key with no menu form (a keypad key) shows no equivalent.
        #expect(MenuKeyEquivalent.make(for: KeyCombo(keyCode: 82, modifiers: .control)) == nil)
    }

    // MARK: Glyphs

    @Test func glyphsAreTheLayoutsOwnShapes() {
        #expect(LayoutGlyph.part(of: .leftHalf) == CGRect(x: 0, y: 0, width: 0.5, height: 1))
        #expect(LayoutGlyph.part(of: .bottomRight) == CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        #expect(LayoutGlyph.part(of: .lastThird).map { abs($0.minX - 2.0 / 3) < 0.01 && $0.maxX == 1 } == true)
        #expect(LayoutGlyph.part(of: .maximize) == CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(LayoutGlyph.part(of: .maximizeHeight).map { $0.minY == 0 && $0.maxY == 1 && $0.width < 1 } == true)
        for action in [TilingAction.smaller, .larger, .nextDisplay, .previousDisplay, .restore] {
            #expect(LayoutGlyph.part(of: action) == nil)
        }
    }

    @MainActor
    @Test func everyActionHasAMenuImage() throws {
        for action in TilingAction.allCases {
            let image = try #require(LayoutGlyph.image(for: action))
            #expect(image.accessibilityDescription == action.title)
        }
        #expect(LayoutGlyph.image(for: .leftHalf)?.isTemplate == true)
    }

    // MARK: Responses

    @Test func outcomesBecomeQuietFeedback() {
        #expect(TilingResponse.to(.moved, of: .leftHalf, appName: "Safari") == .announcement("Left Half"))
        #expect(TilingResponse.to(.unchanged, of: .restore, appName: nil) == .beep)
        #expect(TilingResponse.to(.noWindow, of: .maximize, appName: nil) == .beep)
        #expect(TilingResponse.to(.skipped(.fullScreen), of: .maximize, appName: nil)
            == .toast("Full-screen windows can't be tiled", symbol: "arrow.up.left.and.arrow.down.right"))
        #expect(TilingResponse.to(.appDidNotRespond, of: .center, appName: "Xcode") == .toast("Xcode didn't respond", symbol: "hourglass"))
        #expect(TilingResponse.to(.appDidNotRespond, of: .center, appName: nil) == .toast("The app didn't respond", symbol: "hourglass"))
    }
}
