/// A button of the small toolbar next to an area selection (Lightshot's inline toolbar, PLAN §10.4).
nonisolated enum OverlayTool: Sendable, Equatable {
    case cancel
    case copy
    case save
    case capture
    case scrollVertically
    case scrollHorizontally

    var symbol: String {
        switch self {
        case .cancel: "xmark"
        case .copy: "doc.on.doc"
        case .save: "square.and.arrow.down"
        case .capture: "checkmark"
        case .scrollVertically: "arrow.up.and.down"
        case .scrollHorizontally: "arrow.left.and.right"
        }
    }

    var label: String {
        switch self {
        case .cancel: "Cancel (Esc)"
        case .copy: "Copy (⌘C)"
        case .save: "Save (⌘S)"
        case .capture: "Capture (Return)"
        case .scrollVertically: "Scroll Vertically (Return)"
        case .scrollHorizontally: "Scroll Horizontally (⌥Return)"
        }
    }

    /// What confirming with this tool asks for; nil cancels.
    var intent: OverlayIntent? {
        switch self {
        case .cancel: nil
        case .copy: .copy
        case .save: .save
        case .capture, .scrollVertically: .capture
        case .scrollHorizontally: .alternate
        }
    }

    /// The tools of a normal capture.
    static let captureTools: [Self] = [.cancel, .copy, .save, .capture]
    /// The tools when only a region is asked for (recording, translation).
    static let confirmTools: [Self] = [.cancel, .capture]
    /// The tools before a scrolling capture.
    static let scrollingTools: [Self] = [.cancel, .scrollHorizontally, .scrollVertically]
}
