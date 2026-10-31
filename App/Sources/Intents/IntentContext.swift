/// The running app for App Intents, which macOS performs inside Oriel's own process (PLAN §7.17). Set at launch.
@MainActor
enum IntentContext {
    weak static var controller: AppController?

    /// The app, told that an intent is being performed, so the window of the launch that brought it does not open over it.
    static func require() throws -> AppController {
        guard let controller else { throw OrielIntentError.notReady }
        controller.noteRequest()
        return controller
    }
}
