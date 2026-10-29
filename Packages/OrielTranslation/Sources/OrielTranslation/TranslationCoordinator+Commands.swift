import OrielCore

/// Translation's commands (PLAN §6.5, §17): Translate Under Cursor, whose title follows whether it is on, and
/// Translate File.
extension TranslationCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        [
            ToolCommand(
                id: "translateUnderCursor",
                title: isTranslatingUnderCursor ? "Stop Translating Under Cursor" : "Translate Under Cursor",
                symbol: "character.cursor.ibeam",
                group: .translation,
                defaultShortcut: Self.cursorShortcut,
                route: "translate/cursor"
            ) { [weak self] in
                self?.toggleTranslateUnderCursor()
            },
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
