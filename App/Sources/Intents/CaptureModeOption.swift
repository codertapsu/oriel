import AppIntents

/// What Take a Screenshot captures.
nonisolated enum CaptureModeOption: String, AppEnum {
    case area
    case window
    case screen

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Capture Mode"
    }

    static var caseDisplayRepresentations: [CaptureModeOption: DisplayRepresentation] {
        [
            .area: DisplayRepresentation(title: "Area", subtitle: "Select it on the screen"),
            .window: DisplayRepresentation(title: "Window", subtitle: "Click the window"),
            .screen: DisplayRepresentation(title: "Screen", subtitle: "The display under the pointer, without asking"),
        ]
    }
}
