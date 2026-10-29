import AppIntents

/// Run Oriel Command (PLAN §7.17): anything in the status menu or Settings → Shortcuts, from a shortcut, a Focus
/// filter or an automation.
struct RunCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Oriel Command"
    static let description = IntentDescription(
        "Runs one of Oriel's commands, such as Capture Area, Clipboard History or a window layout.",
        categoryName: "Oriel"
    )

    @Parameter(title: "Command")
    var command: CommandEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$command)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard try IntentContext.require().run(commandID: command.id) else { throw OrielIntentError.commandGone }
        return .result()
    }
}
