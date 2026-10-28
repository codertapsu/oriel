/// The kinds of annotation, also the `type` tag of an item in a saved document.
nonisolated enum AnnotationKind: String, Codable, Sendable, CaseIterable {
    case arrow
    case line
    case rect
    case ellipse
    case freehand
    case highlighter
    case text
    case counter
    case blur
    case pixelate
    case spotlight

    /// The name the Undo menu shows for creating one.
    var actionName: String {
        switch self {
        case .arrow: "Arrow"
        case .line: "Line"
        case .rect: "Rectangle"
        case .ellipse: "Ellipse"
        case .freehand: "Pen"
        case .highlighter: "Highlighter"
        case .text: "Text"
        case .counter: "Step"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .spotlight: "Spotlight"
        }
    }
}
