/// The keystroke HUD's one line: consecutive typing accumulates (`hello`), a shortcut replaces it (`⌘S`). Pure.
nonisolated struct KeystrokeLine: Equatable, Sendable {
    /// The most characters of typed text kept; older ones scroll off the front.
    static let maximumLength = 28

    private(set) var text = ""
    private var endsWithText = false

    /// What the HUD shows; a line of spaces shows as `␣`.
    var displayText: String {
        !text.isEmpty && text.allSatisfy(\.isWhitespace) ? "␣" : text
    }

    mutating func append(_ press: KeystrokeFormatter.Press) {
        if press.isText, endsWithText {
            text = String((text + press.label).suffix(Self.maximumLength))
        } else {
            text = press.label
        }
        endsWithText = press.isText
    }

    mutating func reset() {
        text = ""
        endsWithText = false
    }
}
