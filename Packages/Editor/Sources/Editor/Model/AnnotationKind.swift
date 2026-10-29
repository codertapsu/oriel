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
    /// An object Smart Move lifted out of the image, which moves like an annotation (format version 2).
    case image
    /// The background Smart Move or Simplify filled a hole with; part of the image (format version 2).
    case patch
    /// Simplify's stand-in for a line of text (format version 2).
    case bar

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
        case .image: "Object"
        case .patch: "Fill"
        case .bar: "Bar"
        }
    }

    /// Kinds that only the smart tools make, never a drawing tool.
    static let madeBySmartTools: Set<AnnotationKind> = [.image, .patch, .bar]
}
