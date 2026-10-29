import OrielCore

/// Capture's commands (PLAN §6.5), the capture modes beyond the app's own actions: Capture Text, and Step Capture,
/// whose title follows whether a session is running.
extension CaptureCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        var commands: [ToolCommand] = []
        if textRecognizer != nil {
            commands.append(captureTextCommand)
        }
        commands.append(stepCaptureCommand)
        return commands
    }

    /// `oriel://capture/steps`, no default shortcut. "Start Step Capture", or "Finish Step Capture" while one runs.
    private var stepCaptureCommand: ToolCommand {
        ToolCommand(
            id: "stepCapture",
            title: StepSession.commandTitle(isCapturing: isStepCaptureActive),
            symbol: "list.number",
            group: .capture,
            route: "capture/steps"
        ) { [weak self] in
            self?.toggleStepCapture()
        }
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
