import AppIntents

/// The windows Focus Window can choose from: every window the switcher lists, on every Space.
nonisolated struct WindowQuery: EntityStringQuery {
    func entities(for identifiers: [Int]) async throws -> [WindowEntity] {
        try await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [WindowEntity] {
        try await all().filter { $0.title.localizedCaseInsensitiveContains(string) || $0.appName.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [WindowEntity] {
        try await all()
    }

    @MainActor
    private func all() async throws -> [WindowEntity] {
        try await IntentContext.require().hub.switcher.windows(includeOtherSpaces: true).map(WindowEntity.init)
    }
}
