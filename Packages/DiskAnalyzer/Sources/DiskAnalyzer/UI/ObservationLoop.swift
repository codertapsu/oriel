import Observation

/// Runs `render` now, and again whenever an `@Observable` value it read changes, for as long as `isLive` holds: how the
/// AppKit views follow the model without polling. The change is applied on the next turn of the main actor, after the
/// new value is in place.
enum ObservationLoop {
    static func run(while isLive: @escaping @MainActor () -> Bool, render: @escaping @MainActor () -> Void) {
        guard isLive() else { return }
        withObservationTracking {
            render()
        } onChange: {
            Task { @MainActor in run(while: isLive, render: render) }
        }
    }
}
