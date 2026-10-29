import SwiftUI

/// One capture in the history grid: its thumbnail, when it was taken and where from, and while searching, why it
/// matched: the text around the words found, marked (PLAN §17).
struct HistoryItemView: View {
    let entry: HistoryEntry
    let thumbnailURL: URL
    var query = ""

    var body: some View {
        let snippet = HistorySearch.snippet(for: entry, query: query)
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: thumbnailURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "photo").foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(entry.date, format: .dateTime.month().day().hour().minute())
                .font(.caption)
            Text(entry.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let snippet {
                Text(Self.attributed(snippet))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// The snippet with the words found in the label colour and semibold.
    static func attributed(_ snippet: HistorySnippet) -> AttributedString {
        var text = AttributedString(snippet.text)
        for range in snippet.highlights {
            guard let lower = AttributedString.Index(range.lowerBound, within: text),
                  let upper = AttributedString.Index(range.upperBound, within: text)
            else {
                continue
            }
            text[lower ..< upper].font = .caption2.weight(.semibold)
            text[lower ..< upper].foregroundColor = .primary
        }
        return text
    }
}
