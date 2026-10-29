import Foundation

/// How a destination's link is copied: the link alone, or ready to paste into Markdown or HTML.
public nonisolated enum UploadLinkFormat: String, Codable, CaseIterable, Sendable {
    case url
    case markdown
    case html

    public var title: String {
        switch self {
        case .url: "Link"
        case .markdown: "Markdown"
        case .html: "HTML"
        }
    }

    /// The text to copy. An image becomes an image (`![name](link)`, `<img>`), anything else a link.
    public func text(for link: URL, name: String, isImage: Bool) -> String {
        let address = link.absoluteString
        switch self {
        case .url:
            return address
        case .markdown:
            let label = name.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            // Parentheses would end the link early.
            let target = address.replacingOccurrences(of: "(", with: "%28").replacingOccurrences(of: ")", with: "%29")
                .replacingOccurrences(of: " ", with: "%20")
            return isImage ? "![\(label)](\(target))" : "[\(label)](\(target))"
        case .html:
            let label = Self.escape(name)
            let target = Self.escape(address)
            return isImage ? "<img src=\"\(target)\" alt=\"\(label)\">" : "<a href=\"\(target)\">\(label)</a>"
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
