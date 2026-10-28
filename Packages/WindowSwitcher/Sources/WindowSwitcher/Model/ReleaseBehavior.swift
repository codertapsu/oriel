/// What releasing a shortcut's hold modifiers does (PLAN §7.1.4).
nonisolated enum ReleaseBehavior: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Releasing the modifiers switches to the selected window (instant switching).
    case switchOnRelease
    /// The switcher stays open until Return, Space, a click or Esc. Forced while Sticky Keys is on.
    case keepOpen

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .switchOnRelease: "Switch on release"
        case .keepOpen: "Keep open"
        }
    }
}
