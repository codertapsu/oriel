import SwiftUI
import UniformTypeIdentifiers

/// The terms of one language pair as an editable table (term, translation, note, match case), with adding, removing
/// (Delete or the − button), and importing and exporting CSV and TSV.
struct GlossaryTermsTable: View {
    let glossaries: GlossaryLibraryModel
    let projectID: UUID
    let pair: GlossaryLanguagePair

    @State private var selection = Set<UUID>()
    @State private var imports = false
    @State private var exporting = false
    @State private var exportFormat = GlossaryFileFormat.csv
    @State private var exportDocument: GlossaryFileDocument?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Table(pair.terms, selection: $selection) {
                TableColumn("Term") { term in field("Term", term, \.source) }
                TableColumn("Translation") { term in field("Translation", term, \.target) }
                TableColumn("Note") { term in field("Note", term, \.note) }
                TableColumn("Match Case") { term in
                    Toggle("Match case", isOn: binding(term, \.isCaseSensitive))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .help("Only text with the same capitals matches")
                }
                .width(min: 72, ideal: 80, max: 96)
            }
            .overlay {
                if pair.terms.isEmpty {
                    Text("No terms yet. Add one, or import a CSV or TSV file.")
                        .foregroundStyle(.secondary)
                }
            }
            .onDeleteCommand { removeSelected() }
            HStack(spacing: 8) {
                Button("Add Term", systemImage: "plus") { add() }
                Button("Remove", systemImage: "minus") { removeSelected() }
                    .disabled(selection.isEmpty)
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Import…") { imports = true }
                    .help("Add terms from a CSV or TSV file with the columns source, target, note and case_sensitive")
                Menu("Export") {
                    ForEach(GlossaryFileFormat.allCases) { format in
                        Button("\(format.title)…") { export(format) }
                    }
                }
                .fixedSize()
                .disabled(!pair.terms.contains(where: \.isUsable))
            }
        }
        .fileImporter(isPresented: $imports, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { result in
            if case let .success(url) = result {
                importFile(url)
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: exportFormat.contentType,
            defaultFilename: exportName
        ) { result in
            if case let .failure(error) = result {
                message = "Couldn't export: \(error.localizedDescription)"
            }
        }
        .onChange(of: pair.id) {
            selection = []
            message = nil
        }
    }

    private func field(_ title: String, _ term: GlossaryTerm, _ keyPath: WritableKeyPath<GlossaryTerm, String> & Sendable) -> some View {
        TextField(title, text: binding(term, keyPath), prompt: Text(title))
            .textFieldStyle(.plain)
            .accessibilityLabel(title)
    }

    /// A binding to one field of a term, read from and written to the library, so the table always shows what is
    /// saved.
    private func binding<Value: Sendable>(
        _ term: GlossaryTerm,
        _ keyPath: WritableKeyPath<GlossaryTerm, Value> & Sendable
    ) -> Binding<Value> {
        let glossaries = glossaries
        let projectID = projectID
        let pairID = pair.id
        let termID = term.id
        return Binding(
            get: { glossaries.term(termID, in: pairID, of: projectID)?[keyPath: keyPath] ?? term[keyPath: keyPath] },
            set: { value in
                guard var current = glossaries.term(termID, in: pairID, of: projectID) else { return }
                current[keyPath: keyPath] = value
                glossaries.updateTerm(current, in: pairID, of: projectID)
            }
        )
    }

    private func add() {
        if let term = glossaries.addTerm(to: pair.id, in: projectID) {
            selection = [term.id]
        }
    }

    private func removeSelected() {
        guard !selection.isEmpty else { return }
        glossaries.removeTerms(selection, from: pair.id, of: projectID)
        selection = []
    }

    private func importFile(_ url: URL) {
        let pairID = pair.id
        Task {
            do {
                let text = try await Self.read(url)
                let rows = try GlossaryCSV.parse(text, delimiter: url.pathExtension.lowercased() == "tsv" ? "\t" : nil)
                let count = glossaries.importRows(rows, into: pairID, of: projectID)
                message = "Imported \(count) \(count == 1 ? "term" : "terms") from \(url.lastPathComponent)."
            } catch {
                message = "Couldn't import \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    /// Reads the file off the main thread, in whatever encoding a spreadsheet saved it.
    private nonisolated static func read(_ url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try GlossaryCSV.decode(Data(contentsOf: url))
        }.value
    }

    private func export(_ format: GlossaryFileFormat) {
        exportFormat = format
        exportDocument = GlossaryFileDocument(text: GlossaryCSV.export(pair.terms, format: format))
        exporting = true
    }

    /// "Docs English-Japanese".
    private var exportName: String {
        let project = glossaries.project(projectID)?.name ?? "Glossary"
        let languages = [pair.source, pair.target].map { $0.isEmpty ? "any" : $0 }.joined(separator: "-")
        return "\(project) \(languages)"
    }
}
