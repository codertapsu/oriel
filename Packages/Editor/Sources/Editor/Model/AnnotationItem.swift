import Foundation

/// One annotation on the canvas. `EditorDocument.items` is z-ordered: later items draw on top.
///
/// Blur and pixelate belong to the image: they are drawn over the base image, under the spotlight dimming and
/// every other annotation, so an arrow on top of a blurred area stays sharp.
nonisolated enum AnnotationItem: Sendable, Equatable, Identifiable {
    case arrow(Arrow)
    case line(Line)
    case rect(Box)
    case ellipse(Box)
    case freehand(FreehandPath)
    case highlighter(FreehandPath)
    case text(TextBox)
    case counter(Counter)
    case blur(Region)
    case pixelate(Region)
    case spotlight(Region)

    var id: UUID {
        switch self {
        case let .arrow(arrow): arrow.id
        case let .line(line): line.id
        case let .rect(box), let .ellipse(box): box.id
        case let .freehand(path), let .highlighter(path): path.id
        case let .text(text): text.id
        case let .counter(counter): counter.id
        case let .blur(region), let .pixelate(region), let .spotlight(region): region.id
        }
    }

    var kind: AnnotationKind {
        switch self {
        case .arrow: .arrow
        case .line: .line
        case .rect: .rect
        case .ellipse: .ellipse
        case .freehand: .freehand
        case .highlighter: .highlighter
        case .text: .text
        case .counter: .counter
        case .blur: .blur
        case .pixelate: .pixelate
        case .spotlight: .spotlight
        }
    }

    /// Blur and pixelate: computed from the base image and drawn as part of it.
    var isImageEffect: Bool {
        switch self {
        case .blur, .pixelate: true
        default: false
        }
    }

    /// Blur, pixelate and spotlight: drawn as part of the image, under every vector annotation, whatever their
    /// place in `items`. Hit-testing follows the same visual order.
    var isImageLayer: Bool {
        switch self {
        case .blur, .pixelate, .spotlight: true
        default: false
        }
    }

    /// The colour the item is drawn in, for the items that have one.
    var color: RGBAColor? {
        switch self {
        case let .arrow(arrow): arrow.color
        case let .line(line): line.color
        case let .rect(box), let .ellipse(box): box.color
        case let .freehand(path), let .highlighter(path): path.color
        case let .text(text): text.color
        case let .counter(counter): counter.color
        case .blur, .pixelate, .spotlight: nil
        }
    }
}

extension AnnotationItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    /// Decodes `{"type": "arrow", …the payload's own fields}`.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(AnnotationKind.self, forKey: .type) {
        case .arrow: self = try .arrow(Arrow(from: decoder))
        case .line: self = try .line(Line(from: decoder))
        case .rect: self = try .rect(Box(from: decoder))
        case .ellipse: self = try .ellipse(Box(from: decoder))
        case .freehand: self = try .freehand(FreehandPath(from: decoder))
        case .highlighter: self = try .highlighter(FreehandPath(from: decoder))
        case .text: self = try .text(TextBox(from: decoder))
        case .counter: self = try .counter(Counter(from: decoder))
        case .blur: self = try .blur(Region(from: decoder))
        case .pixelate: self = try .pixelate(Region(from: decoder))
        case .spotlight: self = try .spotlight(Region(from: decoder))
        }
    }

    /// Encodes the payload's fields next to a `type` tag, so saved documents stay readable.
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .type)
        switch self {
        case let .arrow(arrow): try arrow.encode(to: encoder)
        case let .line(line): try line.encode(to: encoder)
        case let .rect(box), let .ellipse(box): try box.encode(to: encoder)
        case let .freehand(path), let .highlighter(path): try path.encode(to: encoder)
        case let .text(text): try text.encode(to: encoder)
        case let .counter(counter): try counter.encode(to: encoder)
        case let .blur(region), let .pixelate(region), let .spotlight(region): try region.encode(to: encoder)
        }
    }
}
