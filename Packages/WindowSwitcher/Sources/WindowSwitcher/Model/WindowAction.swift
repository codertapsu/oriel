/// What the switcher can do to a window without switching to it first (PLAN §1.2, §7.1.3). Every action goes
/// through Accessibility, so it needs an AX element for the window; Oriel's own windows go through AppKit.
public nonisolated enum WindowAction: String, Sendable, CaseIterable {
    /// Presses the window's close button.
    case close
    /// Minimizes the window into the Dock.
    case minimize
    /// Enters full screen, or leaves it when the window is already full screen.
    case toggleFullScreen

    /// The label of the matching hover button and menu command.
    public var title: String {
        switch self {
        case .close: "Close"
        case .minimize: "Minimize"
        case .toggleFullScreen: "Full Screen"
        }
    }
}
