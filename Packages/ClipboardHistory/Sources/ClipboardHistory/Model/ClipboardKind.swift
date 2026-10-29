/// What a clipboard item holds, which decides its icon, its preview and the type filter it falls under.
nonisolated enum ClipboardKind: String, Codable, Sendable, CaseIterable {
    case text
    case richText
    case link
    case color
    case image
    case files
    case other

    var displayName: String {
        switch self {
        case .text: "Text"
        case .richText: "Rich Text"
        case .link: "Link"
        case .color: "Color"
        case .image: "Image"
        case .files: "Files"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "doc.richtext"
        case .link: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .files: "doc.on.doc"
        case .other: "shippingbox"
        }
    }

    /// Whether the item is text at heart, so "Paste as Plain Text" means something for it.
    var isTextual: Bool {
        switch self {
        case .text, .richText, .link, .color: true
        case .image, .files, .other: false
        }
    }
}
