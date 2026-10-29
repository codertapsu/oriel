/// The rich text formats `NSAttributedString` reads.
enum RichTextFormat: Hashable, Sendable {
    case rtf, rtfd, docx, doc, odt

    var title: String {
        switch self {
        case .rtf, .rtfd: "Rich text"
        case .docx, .doc: "Word document"
        case .odt: "OpenDocument text"
        }
    }
}
