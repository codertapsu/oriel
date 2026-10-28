import SharedUI
import SwiftUI

/// The translation history window (PLAN §7.7.6): saved translations with their thumbnails, newest first.
struct TranslationHistoryView: View {
    @Bindable var model: TranslationHistoryModel

    var body: some View {
        NavigationSplitView {
            List(model.entries, selection: $model.selection) { entry in
                row(for: entry).tag(entry.id)
            }
            .overlay {
                if model.entries.isEmpty {
                    ContentUnavailableView(
                        "No Translations",
                        systemImage: "clock",
                        description: Text(model
                            .isEnabled ? "Translations you make appear here." : "Turn on history to keep your translations.")
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if let entry = model.selectedEntry {
                detail(for: entry)
            } else {
                ContentUnavailableView("Select a Translation", systemImage: "character.book.closed")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle("Keep History", isOn: $model.isEnabled)
                    .toggleStyle(.switch)
                    .help("Save translations on this Mac")
                Button("Delete", systemImage: "trash") {
                    if let id = model.selection {
                        Task { await model.delete(id) }
                    }
                }
                .disabled(model.selection == nil)
                Button("Clear History", systemImage: "trash.slash") {
                    Task { await model.deleteAll() }
                }
                .disabled(model.entries.isEmpty)
            }
        }
        .frame(minWidth: 640, minHeight: 400)
    }

    private func row(for entry: TranslationHistoryEntry) -> some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail = model.thumbnails[entry.id] {
                    Image(nsImage: thumbnail).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 40)
            .clipShape(.rect(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary).lineLimit(2)
                Text("\(entry.date.formatted(date: .abbreviated, time: .shortened)) · \(entry.providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func detail(for entry: TranslationHistoryEntry) -> some View {
        List {
            Section {
                ForEach(Array(entry.blocks.enumerated()), id: \.offset) { _, block in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.source).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(block.translation).textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                let languages = [entry.sourceLanguage.map(LanguageCatalog.name(of:)), LanguageCatalog.name(of: entry.targetLanguage)]
                    .compactMap(\.self)
                    .joined(separator: " → ")
                Text("\(languages) · \(entry.providerName)")
            }
        }
        .toolbar {
            Button("Copy Translation", systemImage: "doc.on.doc") {
                Pasteboard.copy(entry.blocks.map(\.translation).joined(separator: "\n\n"))
            }
        }
    }
}
