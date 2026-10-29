import Foundation

/// A named set of colors, in the user's order.
nonisolated struct Palette: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var colors: [PaletteColor]

    init(id: UUID = UUID(), name: String, colors: [PaletteColor] = []) {
        self.id = id
        self.name = name
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, colors
    }

    /// Missing ids and colors are filled in, so a hand-written or older file opens.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Palette"
        colors = try container.decodeIfPresent([Lenient<PaletteColor>].self, forKey: .colors)?.compactMap(\.value) ?? []
    }
}
