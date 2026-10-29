import OrielCore

/// Translation's commands (PLAN §6.5, §17): Translate File.
extension TranslationCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        [
            ToolCommand(
                id: "translateFile",
                title: "Translate File…",
                symbol: "doc.text",
                group: .translation,
                route: "translate/file"
            ) { [weak self] in
                self?.chooseFileToTranslate()
            },
        ]
    }
}
