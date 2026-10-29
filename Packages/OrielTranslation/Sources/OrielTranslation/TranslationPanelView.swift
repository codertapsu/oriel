import SwiftUI

/// The side panel (PLAN §7.7.6): source and translation for every block, copy all or one, swap languages, translate
/// again with another provider or glossary, export.
struct TranslationPanelView: View {
    struct Actions {
        var selectProvider: @MainActor (ProviderID) -> Void
        var selectTarget: @MainActor (String) -> Void
        var selectGlossary: @MainActor (UUID?) -> Void
        var swap: @MainActor () -> Void
        var copyAll: @MainActor () -> Void
        var copy: @MainActor (String) -> Void
        var export: @MainActor (TranslationExporter.Format) -> Void
    }

    let model: TranslationSessionModel
    let glossaries: GlossaryLibraryModel
    let actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)
            Divider()
            if model.blocks.isEmpty {
                ContentUnavailableView(model.isBusy ? "Recognizing Text…" : "No Text", systemImage: "text.viewfinder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.blocks) { block in
                    row(for: block)
                }
                .listStyle(.inset)
            }
            Divider()
            footer
                .padding(10)
        }
        .frame(minWidth: 340, minHeight: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Provider", selection: Binding(get: { model.providerID }, set: { actions.selectProvider($0) })) {
                    ForEach(model.providers) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .labelsHidden()
                Button("Swap Languages", systemImage: "arrow.left.arrow.right", action: actions.swap)
                    .labelStyle(.iconOnly)
                    .disabled(!canSwap)
                    .help("Swap source and target languages")
                Picker("Target Language", selection: Binding(get: { model.targetCode }, set: { actions.selectTarget($0) })) {
                    ForEach(targets, id: \.self) { code in
                        Text(LanguageCatalog.name(of: code)).tag(code)
                    }
                }
                .labelsHidden()
            }
            HStack(spacing: 6) {
                if model.isBusy {
                    ProgressView().controlSize(.small)
                }
                if model.isOffline {
                    Label("Offline", systemImage: "wifi.slash")
                        .foregroundStyle(.orange)
                        .help(ProviderAvailability.offline.message)
                }
                Text(model.statusText)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .font(.caption)
        }
    }

    private func row(for block: TranslationBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !block.source.isEmpty {
                Text(block.source)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack(alignment: .top) {
                Text(block.translation ?? "…")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let translation = block.translation {
                    Button("Copy", systemImage: "doc.on.doc") { actions.copy(translation) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Copy this translation")
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if let translation = block.translation {
                Button("Copy Translation") { actions.copy(translation) }
            }
            if !block.source.isEmpty {
                Button("Copy Original") { actions.copy(block.source) }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Copy All", systemImage: "doc.on.doc", action: actions.copyAll)
                .disabled(model.translatedCount == 0)
            if !glossaries.projects.isEmpty {
                Picker("Glossary", selection: Binding(get: { glossaries.activeProjectID }, set: { actions.selectGlossary($0) })) {
                    Label("No Glossary", systemImage: "book.closed").tag(UUID?.none)
                    Divider()
                    ForEach(glossaries.projects) { project in
                        Label(project.name.isEmpty ? "Untitled" : project.name, systemImage: "character.book.closed")
                            .tag(UUID?.some(project.id))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("The glossary translations use")
            }
            Spacer()
            Menu("Export", systemImage: "square.and.arrow.up") {
                ForEach(TranslationExporter.Format.allCases) { format in
                    Button("\(format.title)…") { actions.export(format) }
                }
            }
            .fixedSize()
            .disabled(model.translatedCount == 0)
        }
    }

    private var canSwap: Bool {
        model.sourceLanguage.map { !LanguageCatalog.isSameLanguage($0, model.targetLanguage) } ?? false
    }

    private var targets: [String] {
        LanguageCatalog.targets.contains(model.targetCode) ? LanguageCatalog.targets : [model.targetCode] + LanguageCatalog.targets
    }
}
