import SharedUI
import SwiftUI

/// The capture history window (PLAN §10.4): a grid of past captures, searchable by the text OCR found in them, the app
/// and the window title. Double-click shows a capture's Quick Access card; the context menu has the rest.
struct HistoryView: View {
    @Bindable var model: HistoryModel
    @State private var confirmsClear = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 380)
        .task { await model.reload() }
        .confirmationDialog("Delete every capture in history?", isPresented: $confirmsClear) {
            Button("Delete All", role: .destructive) {
                Task { await model.clear() }
            }
        } message: {
            Text("The history images are deleted. Files you saved elsewhere stay where they are.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            TextField("Search text in captures, apps and window titles", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .disabled(!model.showsEverything)
            ProBadge(.captureHistory)
            Text(status)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button("Clear…") { confirmsClear = true }
                .disabled(model.entries.isEmpty)
        }
        .padding(12)
    }

    private var status: String {
        let shown = if !model.showsEverything, model.entries.count > HistoryModel.freeCount {
            "The last \(HistoryModel.freeCount) of \(model.entries.count)"
        } else if model.query.isEmpty {
            "\(model.entries.count) captures"
        } else {
            "\(model.filtered.count) of \(model.entries.count)"
        }
        let pending = model.pendingCount
        guard model.isIndexing, pending > 0 else { return shown }
        return "\(shown) · reading text, \(pending) left"
    }

    @ViewBuilder private var content: some View {
        if model.entries.isEmpty {
            ContentUnavailableView(
                "No Captures Yet",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Captures appear here while history is on in Settings → Capture.")
            )
        } else if model.filtered.isEmpty {
            ContentUnavailableView.search(text: model.query)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 14)], spacing: 14) {
                    ForEach(model.filtered) { entry in
                        HistoryItemView(entry: entry, thumbnailURL: model.thumbnailURL(for: entry), query: model.query)
                            .onTapGesture(count: 2) { model.perform?(.open, entry) }
                            .contextMenu { menu(for: entry) }
                            .onDrag { NSItemProvider(contentsOf: model.imageURL(for: entry)) ?? NSItemProvider() }
                    }
                }
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private func menu(for entry: HistoryEntry) -> some View {
        Button("Open") { model.perform?(.open, entry) }
        Button("Copy") { model.perform?(.copy, entry) }
        Button("Save to Folder") { model.perform?(.save, entry) }
        Button("Pin to Screen") { model.perform?(.pin, entry) }
        Button("Annotate") { model.perform?(.annotate, entry) }
        Button("Show in Finder") { model.perform?(.reveal, entry) }
        Divider()
        Button("Delete", role: .destructive) {
            Task { await model.delete(entry) }
        }
    }
}
