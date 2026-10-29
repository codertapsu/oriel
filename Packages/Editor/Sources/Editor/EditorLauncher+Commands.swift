import OrielCore

/// The editor's commands (PLAN §6.5), such as opening a file.
extension EditorLauncher: CommandProviding {
    public var commands: [ToolCommand] {
        []
    }
}
