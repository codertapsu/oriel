/// What an interactive capture asks the user to pick (PLAN §7.2, item 3).
public nonisolated enum CaptureMode: String, CaseIterable, Codable, Sendable {
    /// Drag a rectangle on the frozen screen.
    case area
    /// Click the window under the pointer; the window itself is captured, optionally with its shadow.
    case window
    /// Click a display.
    case screen
    /// The last area again, without asking; falls back to `area` when there is none.
    case previousArea
    /// Select an area, then scroll its content and stitch the frames (PLAN §7.3).
    case scrolling
    /// Every display at once, composed into one image.
    case allDisplays

    /// A name for menus and logs.
    public var title: String {
        switch self {
        case .area: "Capture Area"
        case .window: "Capture Window"
        case .screen: "Capture Screen"
        case .previousArea: "Capture Previous Area"
        case .scrolling: "Scrolling Capture"
        case .allDisplays: "Capture All Displays"
        }
    }
}
