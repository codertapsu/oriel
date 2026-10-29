import AppIntents

/// One thing Oriel can do: an action of the app's own or a command of a feature or tool, so every command,
/// including those of tools added later, is available in Shortcuts.
nonisolated struct CommandEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Oriel Command"
    }

    static var defaultQuery: CommandQuery {
        CommandQuery()
    }

    let id: String
    let title: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", image: .init(systemName: symbol))
    }
}
