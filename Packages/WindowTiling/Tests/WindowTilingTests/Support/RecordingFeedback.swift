import OrielCore
@testable import WindowTiling

/// Feedback that records what it was asked to show, and shows nothing.
@MainActor
final class RecordingFeedback: TilingFeedback {
    private(set) var responses: [TilingResponse] = []
    private(set) var accessibilityRequests: [String] = []
    private(set) var dismissals = 0
    private var openSettings: (@MainActor () -> Void)?

    func respond(_ response: TilingResponse) {
        responses.append(response)
    }

    func askForAccessibility(paneName: String, openSettings: @escaping @MainActor () -> Void) {
        accessibilityRequests.append(paneName)
        self.openSettings = openSettings
    }

    func dismiss() {
        dismissals += 1
    }

    /// Presses the notice's button.
    func pressOpenSettings() {
        openSettings?()
    }
}
