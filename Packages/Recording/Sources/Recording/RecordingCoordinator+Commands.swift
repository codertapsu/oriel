import OrielCore

/// Recording's commands (PLAN §6.5), such as opening a movie in the video editor.
extension RecordingCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        []
    }
}
