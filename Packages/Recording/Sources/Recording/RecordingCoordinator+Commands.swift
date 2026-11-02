import OrielCore

/// Recording's commands (PLAN §6.5), such as opening a movie in the video editor.
extension RecordingCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        let openVideo = ToolCommand(
            id: "openVideoEditor",
            title: "Open Video…",
            symbol: "film",
            group: .library,
            route: "video/open",
            proFeature: .videoEditor
        ) { [weak self] in
            self?.openVideoEditor()
        }
        return [openVideo]
    }
}
