/// The canvas tools, in toolbar order, with the single-key shortcut each answers to.
nonisolated enum EditorTool: String, CaseIterable, Sendable, Identifiable {
    case select
    case arrow
    case line
    case rectangle
    case ellipse
    case pen
    case highlighter
    case text
    case counter
    case blur
    case pixelate
    case spotlight
    case crop

    var id: String {
        rawValue
    }

    /// The button's accessibility label and the first part of its tooltip.
    var title: String {
        switch self {
        case .select: "Select"
        case .arrow: "Arrow"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .text: "Text"
        case .counter: "Numbered Step"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .spotlight: "Spotlight"
        case .crop: "Crop"
        }
    }

    /// The key that picks the tool (PLAN §7.5), lowercase.
    var shortcut: Character {
        switch self {
        case .select: "v"
        case .arrow: "a"
        case .line: "l"
        case .rectangle: "r"
        case .ellipse: "o"
        case .pen: "p"
        case .highlighter: "h"
        case .text: "t"
        case .counter: "n"
        case .blur: "b"
        case .pixelate: "x"
        case .spotlight: "s"
        case .crop: "c"
        }
    }

    var symbolName: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .pen: "scribble"
        case .highlighter: "highlighter"
        case .text: "textformat"
        case .counter: "1.circle"
        case .blur: "drop.halffull"
        case .pixelate: "checkerboard.rectangle"
        case .spotlight: "light.max"
        case .crop: "crop"
        }
    }

    /// Tooltip, e.g. "Arrow (A)".
    var help: String {
        "\(title) (\(String(shortcut).uppercased()))"
    }

    /// The kind of item the tool draws, if it draws one.
    var drawsKind: AnnotationKind? {
        switch self {
        case .select, .crop: nil
        case .arrow: .arrow
        case .line: .line
        case .rectangle: .rect
        case .ellipse: .ellipse
        case .pen: .freehand
        case .highlighter: .highlighter
        case .text: .text
        case .counter: .counter
        case .blur: .blur
        case .pixelate: .pixelate
        case .spotlight: .spotlight
        }
    }

    static func forShortcut(_ character: Character) -> EditorTool? {
        allCases.first { $0.shortcut == character }
    }
}
