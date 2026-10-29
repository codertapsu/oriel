import AppIntents
import OrielCore

/// A window the switcher knows, for Focus Window.
nonisolated struct WindowEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Window"
    }

    static var defaultQuery: WindowQuery {
        WindowQuery()
    }

    /// The window's CGWindowID; App Intents identifies entities by Int, String or UUID.
    let id: Int
    let title: String
    let appName: String

    init(_ window: WindowInfo) {
        id = Int(window.id)
        title = window.title
        appName = window.appName
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title.isEmpty ? appName : title)", subtitle: "\(appName)")
    }
}
