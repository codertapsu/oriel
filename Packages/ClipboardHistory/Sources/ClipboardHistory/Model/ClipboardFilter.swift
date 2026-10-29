/// The type menu next to the search field.
nonisolated enum ClipboardFilter: String, CaseIterable, Sendable {
    case all
    case pinned
    case text
    case images
    case files
    case links
    case colors

    var title: String {
        switch self {
        case .all: "All Types"
        case .pinned: "Pinned"
        case .text: "Text"
        case .images: "Images"
        case .files: "Files"
        case .links: "Links"
        case .colors: "Colors"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .pinned: "pin"
        case .text: ClipboardKind.text.symbol
        case .images: ClipboardKind.image.symbol
        case .files: ClipboardKind.files.symbol
        case .links: ClipboardKind.link.symbol
        case .colors: ClipboardKind.color.symbol
        }
    }

    /// Whether items of `kind` pass. Pinned is about the section, so it passes every kind.
    func includes(_ kind: ClipboardKind) -> Bool {
        switch self {
        case .all, .pinned: true
        case .text: kind == .text || kind == .richText
        case .images: kind == .image
        case .files: kind == .files
        case .links: kind == .link
        case .colors: kind == .color
        }
    }
}
