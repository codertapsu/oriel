import SwiftUI

/// One capture in the history grid: its thumbnail, when it was taken and where from.
struct HistoryItemView: View {
    let entry: HistoryEntry
    let thumbnailURL: URL

    var body: some View {
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
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
