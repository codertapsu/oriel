import CoreGraphics
@testable import OrielTranslation

/// A tooltip that records what it was asked to show.
@MainActor
final class RecordingTooltip: CursorTooltipPresenting {
    enum Event: Equatable {
        case pending
        case shown(String)
        case failed(String)
        case hidden
    }

    private(set) var events: [Event] = []

    var last: Event? {
        events.last
    }

    func showPending(region _: CGRect, pointer _: CGPoint) {
        events.append(.pending)
    }

    func show(_ translation: CursorTranslation, region _: CGRect, pointer _: CGPoint) {
        events.append(.shown(translation.translation))
    }

    func showFailure(_ message: String, region _: CGRect, pointer _: CGPoint) {
        events.append(.failed(message))
    }

    func hide() {
        events.append(.hidden)
    }
}
