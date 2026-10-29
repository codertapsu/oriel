import Foundation
import OrielCore
@testable import OrielTranslation
import Testing

/// Which terms a translation gets from a project, and how the library is kept on disk.
@MainActor
struct GlossaryLibraryTests {
    private let english = Locale.Language(identifier: "en")
    private let japanese = Locale.Language(identifier: "ja")

    private func project() -> GlossaryProject {
        GlossaryProject(name: "Docs", pairs: [
            GlossaryLanguagePair(
                source: "",
                target: "",
                terms: [GlossaryTerm(source: "Oriel", target: "Oriel"), GlossaryTerm(source: "pin", target: "pin")]
            ),
            GlossaryLanguagePair(source: "", target: "ja", terms: [GlossaryTerm(source: "pin", target: "ピン留め")]),
            GlossaryLanguagePair(source: "en", target: "ja", terms: [
                GlossaryTerm(source: "pin", target: "ピン"),
                GlossaryTerm(source: "capture", target: "キャプチャ"),
                GlossaryTerm(source: "unfinished", target: ""),
            ]),
            GlossaryLanguagePair(source: "en", target: "fr", terms: [GlossaryTerm(source: "capture", target: "capture d’écran")]),
        ])
    }

    @Test func theMostSpecificPairWinsAndUnfinishedTermsAreLeftOut() {
        let terms = project().terms(source: english, target: japanese)
        #expect(terms.map(\.target) == ["ピン", "キャプチャ", "Oriel"])
        let british = project().terms(source: Locale.Language(identifier: "en-GB"), target: Locale.Language(identifier: "fr-CA"))
        #expect(british.map(\.target) == ["capture d’écran", "Oriel", "pin"])
    }

    @Test func textInAnUnknownLanguageGetsOnlyPairsForAnyLanguage() {
        let terms = project().terms(source: nil, target: japanese)
        #expect(terms.map(\.target) == ["ピン留め", "Oriel"])
    }

    @Test func caseSensitiveTermsThatDifferOnlyInCaseAreBothKept() {
        let pair = GlossaryLanguagePair(source: "en", target: "fr", terms: [
            GlossaryTerm(source: "Apple", target: "Apple", isCaseSensitive: true),
            GlossaryTerm(source: "apple", target: "pomme", isCaseSensitive: true),
            GlossaryTerm(source: "APPLE", target: "doubled"),
        ])
        let terms = GlossaryProject(name: "Fruit", pairs: [pair]).terms(source: english, target: Locale.Language(identifier: "fr"))
        #expect(terms.map(\.target) == ["Apple", "pomme"])
    }

    @Test func theLibraryHandsTheActiveProjectToTranslations() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let model = GlossaryLibraryModel(store: nil, settings: settings.store)
        let project = model.addProject(named: "Docs")
        let pair = try #require(model.addPair(source: "en", target: "ja", to: project.id))
        let term = try #require(model.addTerm(to: pair.id, in: project.id))
        model.updateTerm(GlossaryTerm(id: term.id, source: "capture", target: "キャプチャ"), in: pair.id, of: project.id)
        #expect(model.glossary(source: english, target: japanese).isEmpty)

        model.activeProjectID = project.id
        let glossary = model.glossary(source: english, target: japanese)
        #expect(glossary.projectID == project.id && glossary.projectName == "Docs")
        #expect(glossary.source == "en" && glossary.target == "ja")
        #expect(glossary.usableTerms.map(\.target) == ["キャプチャ"])

        model.deleteProject(project.id)
        #expect(model.activeProjectID == nil && settings.store[TranslationKeys.activeGlossary].isEmpty)
    }

    @Test func newProjectNamesAreUnique() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let model = GlossaryLibraryModel(store: nil, settings: settings.store)
        #expect([model.addProject(), model.addProject(), model.addProject()].map(\.name) == ["Glossary", "Glossary 2", "Glossary 3"])
    }

    @Test func importsUpdateKnownTermsAndCreateNamedPairs() throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let model = GlossaryLibraryModel(store: nil, settings: settings.store)
        let project = model.addProject()
        let pair = try #require(model.addPair(source: "en", target: "ja", to: project.id))
        let rows = try GlossaryCSV.parse("source,target\npin,ピン\nPIN,ピン留め\n")
        #expect(model.importRows(rows, into: pair.id, of: project.id) == 2)
        #expect(model.project(project.id)?.pairs.first?.terms.map(\.target) == ["ピン留め"])
        let named = try GlossaryCSV.parse("source_language,target_language,source,target\nen,fr,pin,épingle\n")
        model.importRows(named, into: pair.id, of: project.id)
        #expect(model.project(project.id)?.pairs.map(\.title) == ["English → Japanese", "English → French"].map(Self.localized))
    }

    /// Pair titles use the user's language names.
    private static func localized(_ title: String) -> String {
        let names = ["English": "en", "Japanese": "ja", "French": "fr"]
        return title.split(separator: " → ").map { LanguageCatalog.name(of: names[String($0)] ?? "") }.joined(separator: " → ")
    }

    // MARK: - On disk

    @Test func savesAndLoadsTheLibrary() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "oriel-glossaries-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let file = folder.appending(path: "glossaries.json")
        let model = GlossaryLibraryModel(store: GlossaryStore(file: file), settings: settings.store, saveDelay: .zero)
        await model.loadIfNeeded()
        let project = model.addProject(named: "Client")
        let pair = try #require(model.addPair(source: "en", target: "de", to: project.id))
        model.importRows(
            [GlossaryCSV.Row(term: GlossaryTerm(source: "pin", target: "Pin", note: "UI", isCaseSensitive: true))],
            into: pair.id,
            of: project.id
        )
        model.setGoogleGlossary("terms-de", for: project.id)
        await model.saveNow()

        let json = try String(contentsOf: file, encoding: .utf8)
        #expect(json.contains(#""caseSensitive" : true"#) && json.contains(#""googleGlossary" : "terms-de""#))
        let reloaded = GlossaryLibraryModel(store: GlossaryStore(file: file), settings: settings.store)
        await reloaded.loadIfNeeded()
        #expect(reloaded.projects == model.projects)
    }

    @Test func theSingleGlossaryOfEarlierVersionsBecomesAProject() async throws {
        let settings = try TemporarySettings()
        defer { settings.remove() }
        settings.store[TranslationKeys.legacyGlossary] = ["Oriel": "Oriel", "capture": "キャプチャ"]
        let model = GlossaryLibraryModel(store: nil, settings: settings.store)
        await model.loadIfNeeded()
        let project = try #require(model.projects.first)
        #expect(project.name == "Glossary" && model.activeProjectID == project.id)
        #expect(project.pairs.first?.source == "" && project.pairs.first?.target == "")
        #expect(project.pairs.first?.terms.map(\.source) == ["Oriel", "capture"])
        #expect(!settings.store.hasValue(TranslationKeys.legacyGlossary))
    }

    @Test func anUnreadableFileIsSetAsideNotOverwritten() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "oriel-glossaries-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "glossaries.json")
        try Data("{ not json".utf8).write(to: file)
        let settings = try TemporarySettings()
        defer { settings.remove() }
        let model = GlossaryLibraryModel(store: GlossaryStore(file: file), settings: settings.store)
        await model.loadIfNeeded()
        #expect(model.projects.isEmpty && model.loadProblem != nil)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names.count == 1 && names[0].hasPrefix("glossaries.unreadable-"))
    }
}
