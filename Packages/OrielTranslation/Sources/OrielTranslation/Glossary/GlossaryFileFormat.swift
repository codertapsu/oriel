import UniformTypeIdentifiers

/// The files a glossary is imported from and exported to.
enum GlossaryFileFormat: String, CaseIterable, Identifiable, Sendable {
    /// Comma-separated, RFC 4180 quoting, with a header row: `source,target,note,case_sensitive`.
    case csv
    /// Tab-separated with the same header; tabs and line breaks inside a field become spaces.
    case tsv
    /// Two columns, source and target, without a header: what Google Cloud Translation takes to create a
    /// unidirectional glossary.
    case googleCloud

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .csv: "CSV"
        case .tsv: "TSV"
        case .googleCloud: "CSV for Google Cloud"
        }
    }

    var contentType: UTType {
        switch self {
        case .csv, .googleCloud: .commaSeparatedText
        case .tsv: .tabSeparatedText
        }
    }

    var delimiter: Character {
        self == .tsv ? "\t" : ","
    }

    var fileExtension: String {
        self == .tsv ? "tsv" : "csv"
    }
}
