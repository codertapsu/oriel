import AppKit
@testable import ColorPicker
import Foundation
import OrielCore
import Testing

/// The panel's keys and drops, on a controller whose panel is never shown; copies land in `copied`.
@MainActor
final class ColorPanelControllerTests {
    private let directory: URL
    private let model: ColorPickerModel
    private let controller: ColorPanelController
    private var copied: [String] = []

    init() async throws {
        directory = try Fixtures.temporaryDirectory()
        model = Fixtures.model(in: directory)
        await model.load()
        controller = ColorPanelController(model: model)
        controller.copier = { [unowned self] in copied.append($0) }
        model.onChange = { [unowned self] in controller.refresh() }
        model.pick(.hex("#FF8800"))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func numberKeysCopyTheFormatsInOrder() {
        #expect(controller.keyDown(Fixtures.key("1", code: KeyCode.ansi1)))
        #expect(controller.keyDown(Fixtures.key("8", code: KeyCode.ansi8)))
        #expect(controller.keyDown(Fixtures.key("0", code: ColorPanelController.ansiZero)))
        #expect(copied == ["#FF8800", "Color(red: 1, green: 0.533, blue: 0)", "UIColor(red: 1, green: 0.533, blue: 0, alpha: 1)"])
        #expect(!controller.keyDown(Fixtures.key("1", code: KeyCode.ansi1, modifiers: .option)), "with a modifier, a digit is not ours")
        #expect(!controller.isVisible)
    }

    @Test func commandKeysSwitchTabsAndCopyWhatTheTabShows() {
        #expect(controller.keyEquivalent(Fixtures.key("c", code: KeyCode.ansiC, modifiers: .command)))
        #expect(copied.last == "#FF8800")
        #expect(controller.keyEquivalent(Fixtures.key("3", code: KeyCode.ansi3, modifiers: .command)))
        #expect(controller.content.selectedTab == .contrast)
        #expect(controller.keyEquivalent(Fixtures.key("c", code: KeyCode.ansiC, modifiers: .command)))
        #expect(copied.last == "21.00:1 — #000000 on #FFFFFF")
        #expect(!controller.keyDown(Fixtures.key("1", code: KeyCode.ansi1)), "digits copy only on the Color tab")
        #expect(controller.keyEquivalent(Fixtures.key("1", code: KeyCode.ansi1, modifiers: .command)))
        #expect(controller.content.selectedTab == .color)
    }

    @Test func aDroppedSwatchMovesWithinItsPalette() throws {
        var id = UUID()
        model.change { id = $0.addPalette(named: "Brand", colors: [.hex("#111111"), .hex("#222222"), .hex("#333333")]) }
        let entries = try #require(model.library.palette(id)?.colors)
        // Dragging the first color to the gap after the second puts it second.
        #expect(controller.drop(.paletteColor(entries[0].id, entries[0].color), into: id, at: 2))
        #expect(model.library.palette(id)?.colors.map { $0.color.hex() } == ["#222222", "#111111", "#333333"])
        // And the last one to the front.
        #expect(controller.drop(.paletteColor(entries[2].id, entries[2].color), into: id, at: 0))
        #expect(model.library.palette(id)?.colors.map { $0.color.hex() } == ["#333333", "#222222", "#111111"])
        // A color from elsewhere is added where it lands.
        #expect(controller.drop(.color(.hex("#444444")), into: id, at: 1))
        #expect(model.library.palette(id)?.colors.map { $0.color.hex() } == ["#333333", "#444444", "#222222", "#111111"])
    }

    @Test func deletingAPaletteOffersUndo() {
        var id = UUID()
        model.change { id = $0.addPalette(named: "Brand") }
        controller.deletePalette(id)
        #expect(model.library.palettes.isEmpty)
        #expect(controller.content.statusLabel.stringValue == "Deleted “Brand”")
        #expect(!controller.content.undoButton.isHidden)
        // A copy meanwhile says so, and Undo stays.
        controller.copy(.hex)
        #expect(controller.content.statusLabel.stringValue == "Copied HEX")
        #expect(!controller.content.undoButton.isHidden)
        #expect(controller.keyEquivalent(Fixtures.key("z", code: 6, modifiers: .command)))
        #expect(model.library.palettes.map(\.name) == ["Brand"])
        #expect(controller.content.undoButton.isHidden)
    }

    @Test func aColorTypedIntoTheSwatchBecomesTheCurrentOne() {
        controller.content.colorTab.swatch.onColor?(.hex("#00AA55"))
        #expect(model.current == .hex("#00AA55"))
        #expect(model.library.history.first == .hex("#00AA55"))
        #expect(controller.content.colorTab.swatch.field.stringValue == "#00AA55")
    }

    @Test func contrastColorsCanBeSetSwappedAndSummarized() {
        controller.useForContrast(.hex("#777777"), asText: true)
        #expect(controller.content.selectedTab == .contrast)
        #expect(controller.contrastSummary == "4.47:1 — #777777 on #FFFFFF")
        model.change { $0.swapContrastColors() }
        #expect(controller.contrastSummary == "4.47:1 — #FFFFFF on #777777")
    }
}
