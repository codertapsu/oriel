import CoreGraphics
import OrielCore

/// Which display the switcher opens on (PLAN §7.1.3, Settings → Window Switcher → Show on). Focusing a window never
/// moves it to another display.
nonisolated enum PanelPlacement: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The display under the pointer.
    case pointer
    /// The display showing the active app's front window.
    case activeWindow
    /// The main display (System Settings → Displays).
    case mainDisplay

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .pointer: "Display under the pointer"
        case .activeWindow: "Display with the active window"
        case .mainDisplay: "Main display"
        }
    }

    /// The display to open on: the one this placement names when it is known, else the one under the pointer, else
    /// the main display.
    func display(pointer: CGDirectDisplayID?, activeWindow: CGDirectDisplayID?, main: CGDirectDisplayID?) -> CGDirectDisplayID? {
        let named = switch self {
        case .pointer: pointer
        case .activeWindow: activeWindow
        case .mainDisplay: main
        }
        return named ?? pointer ?? main
    }

    /// The display of the active app's front window on the current Space (`entries` are front to back), from the
    /// cached list, so opening the switcher never waits for Accessibility.
    static func activeWindowDisplay(in entries: [WindowEntry], context: FilterContext) -> CGDirectDisplayID? {
        guard let pid = context.activePID else { return nil }
        let window = entries.first { entry in
            entry.info.pid == pid && entry.info.isOnCurrentSpace && !entry.info.isMinimized && !entry.info.isHidden
        }
        return window.flatMap { context.displayID(of: $0.info) }
    }
}
