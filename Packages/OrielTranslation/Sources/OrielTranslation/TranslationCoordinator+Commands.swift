import OrielCore

/// Translation's commands (PLAN §6.5), such as Translate Under Cursor and Translate File.
extension TranslationCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        []
    }
}
