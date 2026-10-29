import Foundation
import Observation
import OrielCore

/// The glossary projects while the app runs: loaded once from `GlossaryStore`, edited in Settings → Translation, and
/// read by every translation for the active project's terms. Edits are saved shortly after the last keystroke, and at
/// once for anything structural (a project or pair added or removed, an import).
@MainActor
@Observable
final class GlossaryLibraryModel {
    private(set) var library = GlossaryLibrary()
    private(set) var isLoaded = false
    /// Why the saved glossaries could not be read, when they could not.
    private(set) var loadProblem: String?

    /// Called with a project's id after it was deleted, so its server-side glossaries (DeepL) can go too.
    @ObservationIgnored var onProjectDeleted: (@MainActor (UUID) -> Void)?

    @ObservationIgnored private let store: GlossaryStore?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private let saveDelay: Duration
    @ObservationIgnored private let log = Log.logger("translation")

    /// `store` nil keeps the glossaries in memory only (tests).
    init(store: GlossaryStore?, settings: SettingsStore, saveDelay: Duration = .milliseconds(600)) {
        self.store = store
        self.settings = settings
        self.saveDelay = saveDelay
    }

    var projects: [GlossaryProject] {
        library.projects
    }

    // MARK: - Loading

    /// Reads the saved glossaries the first time it is called; later calls return at once. A library from before
    /// glossary projects (one list of terms in Settings) becomes a project called "Glossary" for any languages.
    func loadIfNeeded() async {
        if isLoaded {
            return
        }
        if let loading {
            await loading.value
            return
        }
        let task = Task { await load() }
        loading = task
        await task.value
    }

    private func load() async {
        defer {
            isLoaded = true
            loading = nil
        }
        guard let store else {
            migrateLegacyGlossary()
            return
        }
        do {
            if let saved = try await store.load() {
                library = saved
            } else {
                migrateLegacyGlossary()
            }
        } catch {
            log.error("Couldn't read the glossaries: \(error.localizedDescription, privacy: .public)")
            loadProblem = "The saved glossaries couldn't be read, so they were set aside in the Glossaries folder."
            try? await store.setAsideUnreadable()
        }
    }

    private func migrateLegacyGlossary() {
        let legacy = settings[TranslationKeys.legacyGlossary]
        guard !legacy.isEmpty, library.projects.isEmpty else { return }
        let terms = legacy.sorted { $0.key < $1.key }.map { GlossaryTerm(source: $0.key, target: $0.value) }
        let project = GlossaryProject(name: "Glossary", pairs: [GlossaryLanguagePair(source: "", target: "", terms: terms)])
        library.projects = [project]
        settings[TranslationKeys.activeGlossary] = project.id.uuidString
        settings.reset(TranslationKeys.legacyGlossary)
        saveSoon(immediately: true)
    }

    // MARK: - The active project

    /// The project translations use, chosen in Settings, the side panel or the file window; nil for none.
    var activeProjectID: UUID? {
        get {
            let id = UUID(uuidString: settings[TranslationKeys.activeGlossary])
            return library.project(id) == nil ? nil : id
        }
        set {
            settings[TranslationKeys.activeGlossary] = newValue?.uuidString ?? ""
        }
    }

    var activeProject: GlossaryProject? {
        library.project(activeProjectID)
    }

    /// What a translation from `source` into `target` uses: the active project's terms for that pair.
    func glossary(source: Locale.Language?, target: Locale.Language) -> TranslationGlossary {
        library.glossary(project: activeProjectID, source: source, target: target)
    }

    /// The pair a new glossary starts with: from English into the target language in Settings, or from any language
    /// when that target is English.
    var suggestedPair: (source: String, target: String) {
        let target = LanguageCatalog.code(for: LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage]))
        return (target.hasPrefix("en") ? "" : "en", target)
    }

    // MARK: - Projects

    func project(_ id: UUID) -> GlossaryProject? {
        library.project(id)
    }

    @discardableResult
    func addProject(named name: String = "Glossary") -> GlossaryProject {
        let project = GlossaryProject(name: library.uniqueName(name))
        library.projects.append(project)
        saveSoon(immediately: true)
        return project
    }

    func renameProject(_ id: UUID, to name: String) {
        edit(id) { $0.name = name }
    }

    func setGoogleGlossary(_ text: String, for id: UUID) {
        edit(id) { $0.googleGlossary = text }
    }

    func deleteProject(_ id: UUID) {
        guard library.project(id) != nil else { return }
        library.projects.removeAll { $0.id == id }
        if UUID(uuidString: settings[TranslationKeys.activeGlossary]) == id {
            settings[TranslationKeys.activeGlossary] = ""
        }
        saveSoon(immediately: true)
        onProjectDeleted?(id)
    }

    // MARK: - Pairs

    /// Adds the pair to the project, or returns the one it already has.
    @discardableResult
    func addPair(source: String, target: String, to projectID: UUID) -> GlossaryLanguagePair? {
        guard let project = library.project(projectID) else { return nil }
        if let existing = project.pairs.first(where: { $0.source == source && $0.target == target }) {
            return existing
        }
        let pair = GlossaryLanguagePair(source: source, target: target)
        edit(projectID, immediately: true) { $0.pairs.append(pair) }
        return pair
    }

    func removePair(_ pairID: UUID, from projectID: UUID) {
        edit(projectID, immediately: true) { $0.pairs.removeAll { $0.id == pairID } }
    }

    // MARK: - Terms

    func term(_ id: UUID, in pairID: UUID, of projectID: UUID) -> GlossaryTerm? {
        library.project(projectID)?.pairs.first { $0.id == pairID }?.terms.first { $0.id == id }
    }

    /// Adds an empty term for the editor to fill in.
    @discardableResult
    func addTerm(to pairID: UUID, in projectID: UUID) -> GlossaryTerm? {
        let term = GlossaryTerm(source: "", target: "")
        var added = false
        editPair(pairID, in: projectID) { pair in
            pair.terms.append(term)
            added = true
        }
        return added ? term : nil
    }

    func updateTerm(_ term: GlossaryTerm, in pairID: UUID, of projectID: UUID) {
        editPair(pairID, in: projectID) { pair in
            guard let index = pair.terms.firstIndex(where: { $0.id == term.id }), pair.terms[index] != term else { return }
            pair.terms[index] = term
        }
    }

    func removeTerms(_ ids: Set<UUID>, from pairID: UUID, of projectID: UUID) {
        editPair(pairID, in: projectID, immediately: true) { $0.terms.removeAll { ids.contains($0.id) } }
    }

    /// Adds imported rows: rows that name languages go to that pair of the project (added if needed), the others to
    /// `pairID`. A row whose term is already there updates it. Returns how many rows were taken.
    @discardableResult
    func importRows(_ rows: [GlossaryCSV.Row], into pairID: UUID, of projectID: UUID) -> Int {
        guard let project = library.project(projectID), let fallback = project.pairs.first(where: { $0.id == pairID }) else { return 0 }
        var updated = project
        var imported = 0
        for row in rows where row.term.isUsable {
            let source = row.sourceLanguage ?? fallback.source
            let target = row.targetLanguage ?? fallback.target
            let index: Int
            if let existing = updated.pairs.firstIndex(where: { $0.source == source && $0.target == target }) {
                index = existing
            } else {
                updated.pairs.append(GlossaryLanguagePair(source: source, target: target))
                index = updated.pairs.count - 1
            }
            var term = row.term
            let sameTerm = { (other: GlossaryTerm) in other.matchKey == term.matchKey && other.isCaseSensitive == term.isCaseSensitive }
            if let known = updated.pairs[index].terms.firstIndex(where: sameTerm) {
                term.id = updated.pairs[index].terms[known].id
                updated.pairs[index].terms[known] = term
            } else {
                updated.pairs[index].terms.append(term)
            }
            imported += 1
        }
        edit(projectID, immediately: true) { $0 = updated }
        return imported
    }

    // MARK: - Saving

    /// Writes the library now, for example when the editor closes.
    func saveNow() async {
        pendingSave?.cancel()
        pendingSave = nil
        await write()
    }

    private func edit(_ projectID: UUID, immediately: Bool = false, _ change: (inout GlossaryProject) -> Void) {
        guard let index = library.projects.firstIndex(where: { $0.id == projectID }) else { return }
        var project = library.projects[index]
        change(&project)
        guard project != library.projects[index] else { return }
        library.projects[index] = project
        saveSoon(immediately: immediately)
    }

    private func editPair(_ pairID: UUID, in projectID: UUID, immediately: Bool = false, _ change: (inout GlossaryLanguagePair) -> Void) {
        edit(projectID, immediately: immediately) { project in
            guard let index = project.pairs.firstIndex(where: { $0.id == pairID }) else { return }
            change(&project.pairs[index])
        }
    }

    /// Saves after a short pause that the next edit restarts, so typing in a cell does not write on every key.
    private func saveSoon(immediately: Bool = false) {
        guard store != nil else { return }
        pendingSave?.cancel()
        let delay = immediately ? Duration.zero : saveDelay
        pendingSave = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.write()
        }
    }

    private func write() async {
        guard let store else { return }
        let snapshot = library
        do {
            try await store.save(snapshot)
        } catch {
            log.error("Couldn't save the glossaries: \(error.localizedDescription, privacy: .public)")
        }
    }
}
