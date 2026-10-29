import AppIntents

/// Why an Oriel action in Shortcuts did not finish, in words the Shortcuts app shows.
nonisolated enum OrielIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    case cancelled
    case unreadableImage
    case windowGone
    case commandGone
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady: "Oriel is still starting. Try again in a moment."
        case .cancelled: "Cancelled."
        case .unreadableImage: "The file is not an image Oriel can read."
        case .windowGone: "That window is no longer open."
        case .commandGone: "That Oriel command is not available. Its tool may be turned off."
        case let .failed(reason): "\(reason)"
        }
    }
}
