import UniformTypeIdentifiers

/// What a step sequence can be exported as (PLAN §17).
nonisolated enum StepExportFormat: String, CaseIterable, Sendable {
    /// One tall image with numbered headers.
    case png
    /// One step per page, with title and notes.
    case pdf
    /// A Markdown file and a folder of images.
    case markdown
    /// One HTML file with the images in it.
    case html

    /// The export menu's item.
    var menuTitle: String {
        switch self {
        case .png: "One Tall Image (PNG)…"
        case .pdf: "PDF, a Step per Page…"
        case .markdown: "Markdown and Images…"
        case .html: "Web Page (HTML)…"
        }
    }

    var symbol: String {
        switch self {
        case .png: "photo"
        case .pdf: "doc.richtext"
        case .markdown: "text.document"
        case .html: "globe"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .pdf: "pdf"
        case .markdown: "md"
        case .html: "html"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .pdf: .pdf
        case .markdown: UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
        case .html: .html
        }
    }
}
