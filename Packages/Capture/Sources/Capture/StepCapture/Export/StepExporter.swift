import CoreGraphics
import Foundation

/// Writes a step sequence in one of the formats (`StepExportFormat`). Nonisolated: the window calls it from a
/// background task, because it reads every image from disk and encodes.
nonisolated enum StepExporter {
    /// What every format shows besides the steps.
    struct Details: Sendable {
        let title: String
        /// "5 steps · 29 October 2026".
        let subtitle: String
        /// The badges' colour (the user's accent colour).
        let accent: CGColor
        /// A4 or US Letter, for the PDF.
        let paper: CGSize
    }

    static func export(_ items: [StepExportItem], as format: StepExportFormat, details: Details, to url: URL) throws {
        switch format {
        case .png:
            try StepSheetExporter.export(items, title: details.title, subtitle: details.subtitle, accent: details.accent, to: url)
        case .pdf:
            try StepPDFExporter.export(items, title: details.title, accent: details.accent, paper: details.paper, to: url)
        case .markdown:
            try StepMarkdownExporter.export(items, title: details.title, subtitle: details.subtitle, to: url)
        case .html:
            try StepHTMLExporter.export(items, title: details.title, subtitle: details.subtitle, accent: details.accent, to: url)
        }
    }

    /// "5 steps · 29 October 2026".
    static func subtitle(count: Int, date: Date) -> String {
        let steps = switch count {
        case 0: "No steps"
        case 1: "1 step"
        default: "\(count) steps"
        }
        return "\(steps) · \(date.formatted(date: .long, time: .omitted))"
    }
}
