import AppIntents

/// Every command Run Oriel Command can run right now: the app's actions, and the commands of the features and of
/// the tools that are turned on.
nonisolated struct CommandQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CommandEntity] {
        try await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [CommandEntity] {
        try await all().filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [CommandEntity] {
        try await all()
    }

    @MainActor
    private func all() throws -> [CommandEntity] {
        let controller = try IntentContext.require()
        let actions = AppAction.allCases.filter { $0 != .quit }.map { CommandEntity(id: $0.rawValue, title: $0.title, symbol: $0.symbol) }
        let commands = controller.commands.map { CommandEntity(id: $0.id, title: $0.title, symbol: $0.symbol) }
        return actions + commands
    }
}
