import Foundation

/// The panel's search: every word of the query has to appear, ignoring case and accents, in an item's title, text,
/// file names, source app, kind, color or, with `includesImageText`, the text read from an image (Oriel Pro).
nonisolated enum ClipboardSearch {
    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func matches(_ item: ClipboardItem, terms: [String], includesImageText: Bool = true) -> Bool {
        guard !terms.isEmpty else { return true }
        let fields: [String?] = [
            item.title, item.text, item.sourceName, includesImageText ? item.recognizedText : nil, item.kind.displayName, item.colorHex,
        ]
            + (item.fileURLs ?? []).map(\.lastPathComponent)
        return terms.allSatisfy { term in
            fields.contains { $0?.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}
