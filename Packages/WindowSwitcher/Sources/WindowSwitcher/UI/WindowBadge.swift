import OrielCore

/// A window's location or state, shown on its tile (PLAN §1.2, §4.1). Spaces are numbered, never named,
/// because Space identity does not survive a restart.
nonisolated enum WindowBadge: Sendable, Equatable {
    case minimized
    case hidden
    case fullScreen
    /// On another Space, 1-based on its display.
    case space(Int)
    /// On another Space SkyLight could not number.
    case otherSpace
    /// On another display than the panel's, numbered left to right.
    case display(Int)

    /// The tile's text.
    var label: String {
        switch self {
        case .minimized: "Minimized"
        case .hidden: "Hidden"
        case .fullScreen: "Full Screen"
        case let .space(index): "Space \(index)"
        case .otherSpace: "Other Space"
        case let .display(number): "Display \(number)"
        }
    }

    /// The words VoiceOver reads after the title, e.g. "minimized" or "Space 2".
    var spokenLabel: String {
        switch self {
        case .minimized: "minimized"
        case .hidden: "hidden"
        case .fullScreen: "full screen"
        case let .space(index): "Space \(index)"
        case .otherSpace: "on another Space"
        case let .display(number): "Display \(number)"
        }
    }

    /// Badges in reading order. `displayNumber` is the window's display when it differs from the panel's.
    static func badges(for window: WindowInfo, displayNumber: Int? = nil) -> [WindowBadge] {
        var badges: [WindowBadge] = []
        if window.isMinimized {
            badges.append(.minimized)
        }
        if window.isHidden {
            badges.append(.hidden)
        }
        if window.isFullScreen {
            badges.append(.fullScreen)
        } else if !window.isOnCurrentSpace {
            badges.append(window.spaceIndex.map(WindowBadge.space) ?? .otherSpace)
        }
        if let displayNumber {
            badges.append(.display(displayNumber))
        }
        return badges
    }
}
