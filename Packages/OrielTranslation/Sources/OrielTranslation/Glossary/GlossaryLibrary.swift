import Foundation

/// Every glossary project: the contents of `Glossaries/glossaries.json` in Application Support. Glossaries are not
/// secrets, so they are plain JSON that can be backed up, read and diffed.
struct GlossaryLibrary: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int
    var projects: [GlossaryProject]

    init(version: Int = Self.currentVersion, projects: [GlossaryProject] = []) {
        self.version = version
        self.projects = projects
    }

    func project(_ id: UUID?) -> GlossaryProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    /// What a translation from `source` into `target` uses from the project `id`; empty when there is no such project.
    func glossary(project id: UUID?, source: Locale.Language?, target: Locale.Language) -> TranslationGlossary {
        guard let project = project(id) else { return .none }
        return TranslationGlossary(
            projectID: project.id,
            projectName: project.name,
            source: source.map(LanguageCatalog.code(for:)),
            target: LanguageCatalog.code(for: target),
            terms: project.terms(source: source, target: target),
            googleGlossary: project.googleGlossary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// A project name that is not taken yet: "Glossary", "Glossary 2", …
    func uniqueName(_ base: String) -> String {
        let taken = Set(projects.map { $0.name.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) {
            number += 1
        }
        return "\(base) \(number)"
    }

    private enum CodingKeys: String, CodingKey {
        case version, projects
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        projects = try container.decodeIfPresent([GlossaryProject].self, forKey: .projects) ?? []
    }
}
