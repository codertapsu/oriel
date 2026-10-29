import Foundation

/// Reads and writes glossaries as CSV and TSV, so they can come from and go to a spreadsheet, a translation tool or
/// Google Cloud. Reading is forgiving: a byte-order mark, CRLF line ends, quoted fields with line breaks and doubled
/// quotes, a header in any order under the usual names (or none), and optional language columns that send each row
/// to its own language pair.
enum GlossaryCSV {
    /// One imported row: a term and, when the file has language columns, its pair.
    struct Row: Equatable, Sendable {
        var sourceLanguage: String?
        var targetLanguage: String?
        var term: GlossaryTerm

        static func == (lhs: Row, rhs: Row) -> Bool {
            lhs.sourceLanguage == rhs.sourceLanguage && lhs.targetLanguage == rhs.targetLanguage
                && lhs.term.source == rhs.term.source && lhs.term.target == rhs.term.target
                && lhs.term.note == rhs.term.note && lhs.term.isCaseSensitive == rhs.term.isCaseSensitive
        }
    }

    enum ImportError: LocalizedError, Equatable {
        case empty
        case noTerms

        var errorDescription: String? {
            switch self {
            case .empty: "The file is empty."
            case .noTerms: "The file has no terms: each row needs a term and its translation."
            }
        }
    }

    private enum Column {
        case source, target, note, caseSensitive, sourceLanguage, targetLanguage
    }

    // MARK: - Import

    /// A file's text in whatever encoding a spreadsheet saved it (`TextDecoding`): Excel still writes Windows Latin 1
    /// for "CSV" without "UTF-8".
    static func decode(_ data: Data) -> String {
        TextDecoding.string(from: data)
    }

    /// The terms in `text`. The delimiter is a tab when the first line has one and no comma outside quotes, else a
    /// comma, unless `delimiter` says.
    static func parse(_ text: String, delimiter: Character? = nil) throws -> [Row] {
        var text = text
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.empty }
        let separator = delimiter ?? detectDelimiter(text)
        var records = records(text, delimiter: separator).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard !records.isEmpty else { throw ImportError.empty }
        var columns: [Int: Column] = [0: .source, 1: .target, 2: .note, 3: .caseSensitive]
        if let header = headerColumns(records[0]) {
            columns = header
            records.removeFirst()
        }
        let rows = records.compactMap { row(from: $0, columns: columns) }
        guard !rows.isEmpty else { throw ImportError.noTerms }
        return rows
    }

    private static func row(from fields: [String], columns: [Int: Column]) -> Row? {
        var row = Row(term: GlossaryTerm(source: "", target: ""))
        for (index, field) in fields.enumerated() {
            let value = field.trimmingCharacters(in: .whitespacesAndNewlines)
            switch columns[index] {
            case .source: row.term.source = value
            case .target: row.term.target = value
            case .note: row.term.note = value
            case .caseSensitive: row.term.isCaseSensitive = isTrue(value)
            case .sourceLanguage: row.sourceLanguage = languageCode(value)
            case .targetLanguage: row.targetLanguage = languageCode(value)
            case nil: break
            }
        }
        return row.term.isUsable ? row : nil
    }

    /// The column of each header name, or nil when the first row is not a header (it names no source or target).
    private static func headerColumns(_ fields: [String]) -> [Int: Column]? {
        var columns: [Int: Column] = [:]
        for (index, field) in fields.enumerated() {
            let name = field.lowercased().filter { $0.isLetter || $0.isNumber }
            switch name {
            case "source", "term", "sourceterm", "original", "from", "key": columns[index] = .source
            case "target", "translation", "targetterm", "translated", "to", "value": columns[index] = .target
            case "note", "notes", "comment", "comments", "description", "context": columns[index] = .note
            case "casesensitive", "matchcase", "case": columns[index] = .caseSensitive
            case "sourcelanguage", "sourcelang", "fromlanguage", "srclang": columns[index] = .sourceLanguage
            case "targetlanguage", "targetlang", "tolanguage", "tgtlang": columns[index] = .targetLanguage
            default: break
            }
        }
        let values = Set(columns.values)
        return values.contains(.source) && values.contains(.target) ? columns : nil
    }

    private static func isTrue(_ value: String) -> Bool {
        ["true", "yes", "y", "1", "x", "✓", "on"].contains(value.lowercased())
    }

    /// A code as stored: `en`, `zh-Hans`; empty, `*` or "any" for any language.
    private static func languageCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "*", trimmed.lowercased() != "any" else { return "" }
        return LanguageCatalog.code(for: Locale.Language(identifier: trimmed))
    }

    private static func detectDelimiter(_ text: String) -> Character {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        var inQuotes = false
        var commas = 0
        var tabs = 0
        for character in firstLine {
            switch character {
            case "\"": inQuotes.toggle()
            case "," where !inQuotes: commas += 1
            case "\t" where !inQuotes: tabs += 1
            default: break
            }
        }
        return tabs > 0 && tabs >= commas ? "\t" : ","
    }

    /// RFC 4180 records: fields split at `delimiter`, quoted fields may hold delimiters, line breaks and doubled
    /// quotes. Line ends may be LF, CRLF or CR.
    static func records(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var fieldStarted = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where !fieldStarted:
                inQuotes = true
                fieldStarted = true
            case delimiter:
                fields.append(field)
                field = ""
                fieldStarted = false
            case "\r\n", "\n", "\r":
                fields.append(field)
                records.append(fields)
                fields = []
                field = ""
                fieldStarted = false
            default:
                field.append(character)
                fieldStarted = true
            }
        }
        if fieldStarted || !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            records.append(fields)
        }
        return records
    }

    // MARK: - Export

    /// The usable terms as a file: CSV and TSV with a header, Google's format without one.
    static func export(_ terms: [GlossaryTerm], format: GlossaryFileFormat) -> String {
        let usable = terms.filter(\.isUsable)
        var lines: [String] = []
        switch format {
        case .csv:
            lines.append("source,target,note,case_sensitive")
            lines += usable.map { term in
                [term.trimmedSource, term.trimmedTarget, term.note, term.isCaseSensitive ? "true" : "false"].map(quotedCSV)
                    .joined(separator: ",")
            }
        case .tsv:
            lines.append("source\ttarget\tnote\tcase_sensitive")
            lines += usable.map { term in
                [term.trimmedSource, term.trimmedTarget, term.note, term.isCaseSensitive ? "true" : "false"].map(flattened)
                    .joined(separator: "\t")
            }
        case .googleCloud:
            lines += usable.map { [$0.trimmedSource, $0.trimmedTarget].map(quotedCSV).joined(separator: ",") }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A CSV field, quoted when it holds a comma, a quote or a line break.
    static func quotedCSV(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A TSV field: tabs and line breaks become spaces, because TSV has no quoting.
    static func flattened(_ field: String) -> String {
        String(field.map { $0 == "\t" || $0.isNewline ? " " : $0 })
    }
}
