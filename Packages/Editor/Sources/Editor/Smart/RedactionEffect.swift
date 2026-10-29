/// How Smart Redact hides what it found: with the editor's blur or pixelate regions.
nonisolated enum RedactionEffect: String, CaseIterable, Sendable, Identifiable {
    case blur
    case pixelate

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        }
    }

    var kind: AnnotationKind {
        switch self {
        case .blur: .blur
        case .pixelate: .pixelate
        }
    }
}
