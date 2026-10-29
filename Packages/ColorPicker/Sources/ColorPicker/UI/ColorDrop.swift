import AppKit

/// What a drop onto the panel carries: a palette entry dragged within the panel, or a color from anywhere, as an
/// `NSColor` (the system Colors panel, design apps) or as text Oriel can read (`#FF8800`, `rgb(…)`).
enum ColorDrop {
    case paletteColor(UUID, ColorValue)
    case color(ColorValue)

    /// The types to register for.
    static let types: [NSPasteboard.PasteboardType] = [SwatchButton.paletteColorType, .color, .string]

    init?(_ pasteboard: NSPasteboard) {
        guard let item = pasteboard.pasteboardItems?.first else { return nil }
        let color = Self.color(in: item)
        if let id = item.string(forType: SwatchButton.paletteColorType).flatMap(UUID.init(uuidString:)), let color {
            self = .paletteColor(id, color)
        } else if let color {
            self = .color(color)
        } else {
            return nil
        }
    }

    var color: ColorValue {
        switch self {
        case let .paletteColor(_, color), let .color(color): color
        }
    }

    private static func color(in item: NSPasteboardItem) -> ColorValue? {
        if let archived = item.propertyList(forType: .color), let color = NSColor(pasteboardPropertyList: archived, ofType: .color) {
            return ColorValue(color)
        }
        return item.string(forType: .string).flatMap(ColorParser.parse)
    }
}
