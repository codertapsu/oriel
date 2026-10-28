/// A hover button on a tile (PLAN §1.2): act on a window without switching to it.
nonisolated enum TileAction: Sendable, Equatable, CaseIterable {
    case close
    case minimize
    /// Shown instead of minimize on a minimized window.
    case restore
    case toggleFullScreen

    var symbolName: String {
        switch self {
        case .close: "xmark"
        case .minimize: "minus"
        case .restore: "arrow.up.square"
        case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
        }
    }

    var label: String {
        switch self {
        case .close: "Close"
        case .minimize: "Minimize"
        case .restore: "Restore"
        case .toggleFullScreen: "Full Screen"
        }
    }

    /// The buttons for a window: minimize becomes restore when it is minimized.
    static func actions(isMinimized: Bool) -> [TileAction] {
        [.close, isMinimized ? .restore : .minimize, .toggleFullScreen]
    }
}
