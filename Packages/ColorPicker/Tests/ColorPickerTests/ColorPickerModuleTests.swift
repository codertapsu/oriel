@testable import ColorPicker
import Foundation
import OrielCore
import Testing

@MainActor
struct ColorPickerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ColorPickerModule.id == .colorPicker)
        #expect(ColorPickerModule().requiredPermissions.isEmpty)
        #expect(ColorPickerModule().settingsSymbol == "eyedropper")
    }

    /// The ids, defaults and routes asked for: ⌃⇧C picks, and Color Picker has no default shortcut.
    @Test func itsCommandsAreTheOnesAskedFor() throws {
        let commands = ColorPickerModule().commands
        #expect(commands.map(\.id) == ["pickColor", "openColorPicker"])
        let pick = try #require(commands.first)
        #expect(pick.title == "Pick Color")
        #expect(pick.group == .tools)
        #expect(pick.defaultShortcut == KeyCombo(keyCode: KeyCode.ansiC, modifiers: [.control, .shift]))
        #expect(pick.defaultShortcut?.description == "⌃⇧C")
        #expect(pick.shortcutKey.name == "shortcuts.pickColor")
        #expect(pick.route == "color/pick")
        let open = try #require(commands.last)
        #expect(open.title == "Color Picker")
        #expect(open.group == .tools)
        #expect(open.defaultShortcut == nil)
        #expect(open.route == "color")
    }

    @Test func activationLoadsTheLibraryAndDeactivationLetsGo() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var saved = ColorLibrary()
        saved.record(.hex("#336699"), limit: 20)
        try await ColorStore(directory: directory).save(saved, revision: 1)

        let module = ColorPickerModule(sampler: FakeSampler([]), directory: directory, copier: { _ in })
        await module.activate(context: Fixtures.context(settings: Fixtures.readOnlySettings()))
        #expect(module.isActive)
        #expect(module.model?.library == saved)
        #expect(module.model?.current == .hex("#336699"))
        #expect(module.pickShortcutDescription == "⌃⇧C")
        await module.deactivate()
        #expect(!module.isActive)
        #expect(module.model == nil && module.panel == nil)
    }
}

@MainActor
struct ColorPickerModelTests {
    @Test func aPickGoesFirstInRecentAndIsSaved() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = Fixtures.model(in: directory)
        await model.load()
        var changes = 0
        model.onChange = { changes += 1 }
        model.pick(.hex("#FF8800"))
        model.pick(.hex("#336699"))
        #expect(model.current == .hex("#336699"))
        #expect(model.library.history == [.hex("#336699"), .hex("#FF8800")])
        #expect(changes == 2)
        await model.flush()
        #expect(await ColorStore(directory: directory).load().history == model.library.history)
    }

    @Test func undoBringsBackTheLastDeletionOnly() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = Fixtures.model(in: directory)
        await model.load()
        var id = UUID()
        model.change { id = $0.addPalette(named: "Brand", colors: [.hex("#FF8800")]) }
        model.change(undoMessage: "Deleted “Brand”") { $0.deletePalette(id) }
        #expect(model.library.palettes.isEmpty)
        #expect(model.undoState?.message == "Deleted “Brand”")
        model.undo()
        #expect(model.library.palettes.map(\.name) == ["Brand"])
        #expect(model.undoState == nil)

        model.change(undoMessage: "Deleted “Brand”") { $0.deletePalette(id) }
        model.pick(.hex("#000000"))
        #expect(model.undoState == nil, "another change makes Undo forget, or it would undo that too")
    }

    @Test func showingAColorDoesNotRecordIt() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = Fixtures.model(in: directory)
        await model.load()
        model.show(.hex("#ABCDEF"))
        #expect(model.current == .hex("#ABCDEF"))
        #expect(model.library.history.isEmpty)
    }
}
