import AppIntents

/// Focus Window (PLAN §7.17): brings a window to the front, on any Space, as the switcher does.
struct FocusWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Focus Window"
    static let description = IntentDescription(
        "Brings a window to the front, switching to its Space if needed. Needs Accessibility, like the window switcher.",
        categoryName: "Windows"
    )

    @Parameter(title: "Window")
    var window: WindowEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Focus \(\.$window)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard try await IntentContext.require().hub.switcher.focus(windowID: UInt32(window.id)) else {
            throw OrielIntentError.windowGone
        }
        return .result()
    }
}
