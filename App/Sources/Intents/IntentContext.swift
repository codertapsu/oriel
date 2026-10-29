/// The running app for App Intents, which macOS performs inside Oriel's own process (PLAN §7.17). Set at launch.
@MainActor
enum IntentContext {
    weak static var controller: AppController?

    static func require() throws -> AppController {
        guard let controller else { throw OrielIntentError.notReady }
        return controller
    }
}
