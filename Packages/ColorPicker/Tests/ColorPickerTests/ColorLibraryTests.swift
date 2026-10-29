@testable import ColorPicker
import Foundation
import Testing

struct ColorLibraryTests {
    @Test func historyKeepsTheNewestFirstUpToItsLimit() {
        var library = ColorLibrary()
        for index in 0 ..< 30 {
            library.record(ColorValue(red: Double(index) / 30, green: 0, blue: 0), limit: 20)
        }
        #expect(library.history.count == 20)
        #expect(library.history.first == ColorValue(red: 29.0 / 30, green: 0, blue: 0))
        library.trimHistory(to: 5)
        #expect(library.history.count == 5)
        library.trimHistory(to: 0)
        #expect(library.history.count == 1, "a limit below one still keeps the newest pick")
    }

    @Test func aRepeatedPickMovesUpInsteadOfAppearingTwice() {
        var library = ColorLibrary()
        library.record(.hex("#FF8800"), limit: 20)
        library.record(.hex("#336699"), limit: 20)
        library.record(ColorValue(red: 1, green: 136.0 / 255 + 0.000_5, blue: 0), limit: 20)
        #expect(library.history.map { $0.hex() } == ["#FF8800", "#336699"])
        library.removeFromHistory(at: 1)
        library.removeFromHistory(at: 7)
        #expect(library.history.map { $0.hex() } == ["#FF8800"])
        library.clearHistory()
        #expect(library.history.isEmpty)
    }

    @Test func palettesCanBeAddedRenamedReorderedAndDeleted() throws {
        var library = ColorLibrary()
        let first = library.addPalette()
        let second = library.addPalette(named: "  Brand  ")
        let third = library.addPalette(named: "")
        #expect(library.palettes.map(\.name) == ["Palette 1", "Brand", "Palette 2"], "the first free number")
        library.renamePalette(first, to: "Greys")
        library.renamePalette(second, to: "   ")
        #expect(library.palettes.map(\.name) == ["Greys", "Brand", "Palette 2"])
        library.movePalette(third, to: 0)
        #expect(library.palettes.map(\.id) == [third, first, second])
        library.movePalette(third, to: 99)
        #expect(library.palettes.map(\.id) == [first, second, third])
        library.deletePalette(second)
        #expect(library.palettes.map(\.id) == [first, third])
        #expect(library.nextPaletteName == "Palette 1")
        library.renamePalette(third, to: "palette 1")
        #expect(library.nextPaletteName == "Palette 2", "names are compared ignoring case")
        #expect(try #require(library.palette(first)).name == "Greys")
    }

    @Test func colorsCanBeAddedMovedRenamedAndRemoved() throws {
        var library = ColorLibrary()
        let brand = library.addPalette(named: "Brand", colors: [.hex("#FF8800"), .hex("#FF8800"), .hex("#336699")])
        let other = library.addPalette(named: "Other")
        #expect(try #require(library.palette(brand)).colors.count == 2, "a palette holds each color once")
        let addedID = library.add(.hex("#00AA55"), toPalette: brand, at: 0)
        let added = try #require(addedID)
        let again = library.add(.hex("#00AA55"), toPalette: brand)
        #expect(again == added, "adding a color again returns the one there")
        #expect(library.palette(brand)?.colors.map { $0.color.hex() } == ["#00AA55", "#FF8800", "#336699"])

        library.moveColor(added, toPalette: brand, at: 2)
        #expect(library.palette(brand)?.colors.map { $0.color.hex() } == ["#FF8800", "#336699", "#00AA55"])
        library.moveColor(added, toPalette: other, at: 0)
        #expect(library.palette(brand)?.colors.count == 2)
        #expect(library.palette(other)?.colors.map(\.id) == [added])
        #expect(library.paletteColor(added)?.paletteID == other)

        library.renameColor(added, to: "  Mint ")
        #expect(library.paletteColor(added)?.color.name == "Mint")
        library.renameColor(added, to: "")
        #expect(library.paletteColor(added)?.color.name == nil)
        library.removeColor(added)
        #expect(try #require(library.palette(other)).colors.isEmpty)
        let nowhere = library.add(.white, toPalette: UUID())
        #expect(nowhere == nil)
    }

    @Test func movingAColorIntoAPaletteThatHasItMergesThem() throws {
        var library = ColorLibrary()
        let first = library.addPalette(named: "A", colors: [.hex("#FF8800")])
        let second = library.addPalette(named: "B", colors: [.hex("#FF8800")])
        let moving = try #require(library.palette(first)?.colors.first?.id)
        library.moveColor(moving, toPalette: second, at: 0)
        #expect(library.palette(first)?.colors.isEmpty == true)
        #expect(library.palette(second)?.colors.count == 1)
    }

    @Test func theContrastColorsSwap() {
        var library = ColorLibrary(contrastText: .hex("#123456"), contrastBackground: .hex("#FEDCBA"))
        library.swapContrastColors()
        #expect(library.contrastText == .hex("#FEDCBA") && library.contrastBackground == .hex("#123456"))
    }
}
