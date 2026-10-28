import Foundation
import UniformTypeIdentifiers

/// The side panel's export formats (PLAN §7.7.6): TXT, Markdown and the annotated PNG.
enum TranslationExporter {
    enum Format: String, CaseIterable, Identifiable {
        case text
        case markdown
        case annotatedImage

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .text: "Text"
            case .markdown: "Markdown"
            case .annotatedImage: "Annotated PNG"
            }
        }

        var contentType: UTType {
            switch self {
            case .text: .plainText
            case .markdown: UTType(filenameExtension: "md") ?? .plainText
            case .annotatedImage: .png
            }
        }

        var fileExtension: String {
            switch self {
            case .text: "txt"
            case .markdown: "md"
            case .annotatedImage: "png"
            }
        }
    }

    /// The translations, one block per paragraph.
    static func plainText(_ blocks: [TranslationBlock]) -> String {
        blocks.compactMap(\.translation).joined(separator: "\n\n") + "\n"
    }

    /// Each block's source as a quote followed by its translation, under a line naming the languages and provider.
    static func markdown(_ blocks: [TranslationBlock], source: String?, target: String, provider: String) -> String {
        let languages = [source.map(LanguageCatalog.name(of:)), LanguageCatalog.name(of: target)].compactMap(\.self)
            .joined(separator: " → ")
        var lines = ["# Translation", "", "*\(languages) · \(provider)*"]
        for block in blocks {
            lines.append("")
            if !block.source.isEmpty {
                lines += block.source.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }
                lines.append("")
            }
            lines.append(block.translation ?? "*(not translated)*")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// "Translation 2026-10-29 at 10.12.txt", like screenshots are named.
    static func suggestedFileName(for format: Format, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Translation \(formatter.string(from: date)).\(format.fileExtension)"
    }
}
