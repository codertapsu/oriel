import Foundation

/// One color in a palette, with the name the user gave it, if any (exports use it: `--brand-orange`).
nonisolated struct PaletteColor: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var color: ColorValue
    var name: String?

    init(id: UUID = UUID(), color: ColorValue, name: String? = nil) {
        self.id = id
        self.color = color
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id, color, name
    }

    /// A color without an id (a hand-written or older file) gets a new one, and a bare hex string is a color too.
    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let hex = try? single.decode(String.self) {
            guard let color = ColorValue(hex: hex) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "“\(hex)” is not a hex color")
            }
            self.init(color: color)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            color: container.decode(ColorValue.self, forKey: .color),
            name: container.decodeIfPresent(String.self, forKey: .name).flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
