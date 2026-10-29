import Foundation

/// The library on disk, `library.json`:
///
/// ```json
/// { "version": 1,
///   "history": [{"red": 1, "green": 0.533, "blue": 0, "alpha": 1}],
///   "palettes": [{"id": "…", "name": "Brand", "colors": [{"id": "…", "color": {…}, "name": "Orange"}]}],
///   "contrastText": {…}, "contrastBackground": {…} }
/// ```
///
/// Colors are extended sRGB components (`ColorValue`). Reading is forgiving, which is how older files migrate: a file
/// without a version is version 0, colors may be hex strings, missing ids and names are filled in, and an entry that
/// cannot be read is skipped rather than failing the file. A file from a newer Oriel is refused, so this one never
/// overwrites what it does not understand.
nonisolated enum ColorLibraryFile {
    static let currentVersion = 1

    enum ReadError: Error, Equatable {
        /// Written by a newer Oriel, whose format this one cannot be sure to keep.
        case newerVersion(Int)
    }

    static func decode(_ data: Data) throws -> ColorLibrary {
        // The version first: a newer file may not even have today's shape.
        let version = try JSONDecoder().decode(Version.self, from: data).version ?? 0
        guard version <= currentVersion else { throw ReadError.newerVersion(version) }
        let file = try JSONDecoder().decode(Contents.self, from: data)
        return ColorLibrary(
            history: file.history,
            palettes: file.palettes,
            contrastText: file.contrastText,
            contrastBackground: file.contrastBackground
        )
    }

    static func encode(_ library: ColorLibrary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Contents(library))
    }

    private struct Version: Decodable {
        var version: Int?
    }

    private struct Contents: Codable {
        var version: Int
        var history: [ColorValue]
        var palettes: [Palette]
        var contrastText: ColorValue
        var contrastBackground: ColorValue

        init(_ library: ColorLibrary) {
            version = ColorLibraryFile.currentVersion
            history = library.history
            palettes = library.palettes
            contrastText = library.contrastText
            contrastBackground = library.contrastBackground
        }

        private enum CodingKeys: String, CodingKey {
            case version, history, palettes, contrastText, contrastBackground
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
            history = try container.decodeIfPresent([Lenient<ColorValue>].self, forKey: .history)?.compactMap(\.value) ?? []
            palettes = try container.decodeIfPresent([Lenient<Palette>].self, forKey: .palettes)?.compactMap(\.value) ?? []
            contrastText = (try? container.decodeIfPresent(ColorValue.self, forKey: .contrastText)) ?? .black
            contrastBackground = (try? container.decodeIfPresent(ColorValue.self, forKey: .contrastBackground)) ?? .white
        }
    }
}
