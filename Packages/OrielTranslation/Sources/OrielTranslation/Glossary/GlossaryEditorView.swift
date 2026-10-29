import SwiftUI

/// The glossary editor (PLAN §17), a sheet in Settings → Translation: glossary projects on the left; on the right the
/// selected project's name, its language pairs, an editable table of the pair's terms with CSV and TSV import and
/// export, and the Google Cloud glossary the project maps to.
struct GlossaryEditorView: View {
    let glossaries: GlossaryLibraryModel
    let onDone: @MainActor () -> Void

    @State private var projectID: UUID?
    @State private var pairID: UUID?
    @State private var addsPair = false
    @State private var newPairSource = "en"
    @State private var newPairTarget = ""
    @State private var confirmsDeletion = false

    /// Opens on the active project (else the first) and its first pair, so the first frame already shows them.
    init(glossaries: GlossaryLibraryModel, onDone: @escaping @MainActor () -> Void) {
        self.glossaries = glossaries
        self.onDone = onDone
        let project = glossaries.activeProject ?? glossaries.projects.first
        _projectID = State(initialValue: project?.id)
        _pairID = State(initialValue: project?.pairs.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 210)
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Text("Glossaries are saved on this Mac as they are edited.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 740, height: 500)
        .task {
            await glossaries.loadIfNeeded()
            if projectID.flatMap(glossaries.project) == nil {
                selectProject(glossaries.activeProjectID ?? glossaries.projects.first?.id)
            }
            (newPairSource, newPairTarget) = glossaries.suggestedPair
        }
        .confirmationDialog(deletionTitle, isPresented: $confirmsDeletion) {
            Button("Delete", role: .destructive) { deleteSelectedProject() }
        } message: {
            Text("Its terms are deleted too. This can't be undone.")
        }
    }

    private var selectedProject: GlossaryProject? {
        projectID.flatMap(glossaries.project)
    }

    // MARK: - Projects

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { projectID }, set: { selectProject($0) })) {
                ForEach(glossaries.projects) { project in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name.isEmpty ? "Untitled" : project.name)
                            .lineLimit(1)
                        Text(Self.summary(of: project))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(project.id)
                    .accessibilityElement(children: .combine)
                }
            }
            .listStyle(.sidebar)
            Divider()
            HStack(spacing: 2) {
                Button("Add Glossary", systemImage: "plus") { addProject() }
                    .help("Add a glossary project")
                Button("Delete Glossary", systemImage: "minus") { confirmsDeletion = true }
                    .disabled(projectID == nil)
                    .help("Delete the selected glossary")
                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    private static func summary(of project: GlossaryProject) -> String {
        let pairs = project.pairs.count
        let terms = project.termCount
        return "\(terms) \(terms == 1 ? "term" : "terms") · \(pairs) \(pairs == 1 ? "language pair" : "language pairs")"
    }

    private var deletionTitle: String {
        "Delete “\(selectedProject?.name ?? "this glossary")”?"
    }

    private func addProject() {
        let project = glossaries.addProject()
        let suggested = glossaries.suggestedPair
        if let pair = glossaries.addPair(source: suggested.source, target: suggested.target, to: project.id) {
            pairID = pair.id
        }
        projectID = project.id
    }

    private func deleteSelectedProject() {
        guard let projectID else { return }
        let index = glossaries.projects.firstIndex { $0.id == projectID } ?? 0
        glossaries.deleteProject(projectID)
        let remaining = glossaries.projects
        selectProject(remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id)
    }

    private func selectProject(_ id: UUID?) {
        projectID = id
        pairID = id.flatMap(glossaries.project)?.pairs.first?.id
    }

    // MARK: - The selected project

    @ViewBuilder private var detail: some View {
        if let project = selectedProject {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name", text: Binding(
                    get: { glossaries.project(project.id)?.name ?? "" },
                    set: { [glossaries] in glossaries.renameProject(project.id, to: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                pairBar(project)
                if let pair = project.pairs.first(where: { $0.id == pairID }) {
                    GlossaryTermsTable(glossaries: glossaries, projectID: project.id, pair: pair)
                } else {
                    ContentUnavailableView {
                        Label("No Language Pairs", systemImage: "character.book.closed")
                    } description: {
                        Text("Add the languages to translate from and into, then list the terms for them.")
                    } actions: {
                        Button("Add Language Pair…") { addsPair = true }
                    }
                    .frame(maxHeight: .infinity)
                }
                GlossaryGoogleField(glossaries: glossaries, projectID: project.id)
            }
            .padding(16)
        } else if glossaries.projects.isEmpty {
            ContentUnavailableView {
                Label("No Glossaries", systemImage: "character.book.closed")
            } description: {
                Text("A glossary keeps product names and terms translated the same way, by every provider.")
            } actions: {
                Button("Add Glossary") { addProject() }
            }
        } else {
            ContentUnavailableView("Select a Glossary", systemImage: "character.book.closed")
        }
    }

    private func pairBar(_ project: GlossaryProject) -> some View {
        HStack(spacing: 8) {
            Picker("Languages", selection: $pairID) {
                ForEach(project.pairs) { pair in
                    Text("\(pair.title)  (\(pair.terms.count))").tag(UUID?.some(pair.id))
                }
            }
            .fixedSize()
            .disabled(project.pairs.isEmpty)
            Button { addsPair = true } label: { Self.symbol("plus") }
                .accessibilityLabel("Add Language Pair…")
                .help("Add a language pair")
                .popover(isPresented: $addsPair, arrowEdge: .bottom) { addPairForm(project) }
            Button {
                guard let pairID else { return }
                glossaries.removePair(pairID, from: project.id)
                self.pairID = glossaries.project(project.id)?.pairs.first?.id
            } label: {
                Self.symbol("minus")
            }
            .accessibilityLabel("Remove Language Pair")
            .disabled(pairID == nil)
            .help("Remove this language pair and its terms")
            Spacer()
        }
    }

    private func addPairForm(_ project: GlossaryProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Language Pair").font(.headline)
            languagePicker("From", selection: $newPairSource)
            languagePicker("Into", selection: $newPairTarget)
            Text("“Any language” suits names that stay the same, whatever the text is written in.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { addsPair = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let pair = glossaries.addPair(source: newPairSource, target: newPairTarget, to: project.id) {
                        pairID = pair.id
                    }
                    addsPair = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    /// A button's symbol in a fixed box, so + and − buttons come out the same size.
    private static func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .frame(width: 14, height: 14)
    }

    private func languagePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("Any language").tag("")
            Divider()
            ForEach(LanguageCatalog.targets, id: \.self) { code in
                Text(LanguageCatalog.name(of: code)).tag(code)
            }
        }
    }
}
