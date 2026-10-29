/// The calls `DeepLGlossaryBook` makes; `DeepLProvider` answers them with its key and endpoint.
protocol DeepLGlossaryClient: Sendable {
    /// The pairs DeepL glossaries support, as `en>ja`.
    func glossaryLanguagePairs() async throws -> Set<String>
    /// Creates the glossary and returns its id.
    func createGlossary(_ spec: DeepLGlossarySpec) async throws -> String
    func deleteGlossary(_ id: String) async throws
}
