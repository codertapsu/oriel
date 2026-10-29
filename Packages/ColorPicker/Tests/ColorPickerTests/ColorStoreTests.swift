@testable import ColorPicker
import Foundation
import Testing

struct ColorStoreTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "ColorStoreTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleLibrary() -> ColorLibrary {
        var library = ColorLibrary(contrastText: .hex("#222222"), contrastBackground: .hex("#FAFAFA"))
        library.record(.hex("#FF8800"), limit: 20)
        library.record(ColorValue(displayP3: SIMD3(1, 0, 0)), limit: 20)
        let brand = library.addPalette(named: "Brand", colors: [.hex("#336699"), .hex("#FF880080")])
        if let first = library.palette(brand)?.colors.first?.id {
            library.renameColor(first, to: "Ocean")
        }
        return library
    }

    @Test func theLibrarySurvivesARestartExactly() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = sampleLibrary()
        try await ColorStore(directory: directory).save(library, revision: 1)
        let reopened = await ColorStore(directory: directory).load()
        #expect(reopened == library)
        // Extended components are kept as they are, not clipped.
        #expect(reopened.history.first?.isInSRGBGamut == false)
    }

    @Test func aMissingFileIsAnEmptyLibrary() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(await ColorStore(directory: directory).load() == ColorLibrary())
    }

    /// Version 0 had no version key, hex strings for colors and no ids; it opens, and is saved back as version 1.
    @Test func anOlderFileMigrates() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = """
        {"history": ["#FF8800", "#336699", 42],
         "palettes": [{"name": "Brand", "colors": ["#123456", {"color": "#ABCDEF", "name": "Sky"}, "oops"]},
                      {"colors": []}]}
        """
        try Data(old.utf8).write(to: directory.appending(path: ColorStore.fileName))
        let store = ColorStore(directory: directory)
        let library = await store.load()
        #expect(library.history.map { $0.hex() } == ["#FF8800", "#336699"], "an unreadable entry is skipped")
        #expect(library.palettes.map(\.name) == ["Brand", "Palette"])
        #expect(library.palettes.first?.colors.map { $0.color.hex() } == ["#123456", "#ABCDEF"])
        #expect(library.palettes.first?.colors.last?.name == "Sky")
        #expect(library.contrastText == .black && library.contrastBackground == .white)
        try await store.save(library, revision: 1)
        let written = try String(contentsOf: directory.appending(path: ColorStore.fileName), encoding: .utf8)
        #expect(written.contains("\"version\" : 1"))
        #expect(await ColorStore(directory: directory).load() == library)
    }

    /// A newer Oriel's file is neither read as something else nor overwritten.
    @Test func aNewerFileIsLeftAlone() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: ColorStore.fileName)
        let newer = Data(#"{"version": 9, "swatches": {"new": "shape"}}"#.utf8)
        try newer.write(to: url)
        let store = ColorStore(directory: directory)
        #expect(await store.load() == ColorLibrary())
        #expect(await store.isReadOnly)
        try await store.save(sampleLibrary(), revision: 1)
        #expect(try Data(contentsOf: url) == newer)
    }

    @Test func aDamagedFileIsSetAsideAndTheLibraryStartsAfresh() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{not json".utf8).write(to: directory.appending(path: ColorStore.fileName))
        let store = ColorStore(directory: directory)
        #expect(await store.load() == ColorLibrary())
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names.contains { $0.hasPrefix("library-unreadable-") })
        let fresh = sampleLibrary()
        try await store.save(fresh, revision: 1)
        #expect(await ColorStore(directory: directory).load() == fresh)
    }

    @Test func anOlderRevisionNeverOverwritesANewerOne() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ColorStore(directory: directory)
        var newer = ColorLibrary()
        newer.record(.hex("#00FF00"), limit: 20)
        try await store.save(newer, revision: 2)
        try await store.save(ColorLibrary(), revision: 1)
        #expect(await ColorStore(directory: directory).load() == newer)
    }
}
