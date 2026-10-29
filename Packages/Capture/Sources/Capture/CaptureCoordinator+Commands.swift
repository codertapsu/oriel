import OrielCore

/// Capture's commands (PLAN §6.5), the capture modes beyond the app's own actions, such as Capture Text.
extension CaptureCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        var commands: [ToolCommand] = []
        if textRecognizer != nil {
            commands.append(captureTextCommand)
        }
        return commands
    }

    /// ⌃⇧O, `oriel://capture/text`. Offered only with on-device OCR.
    private var captureTextCommand: ToolCommand {
        ToolCommand(
            id: "captureText",
            title: "Capture Text",
            symbol: "text.viewfinder",
            group: .capture,
            defaultShortcut: KeyCombo(keyCode: KeyCode.ansiO, modifiers: [.control, .shift]),
            route: "capture/text"
        ) { [weak self] in
            Task { await self?.captureText() }
        }
    }
}
