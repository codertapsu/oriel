/// A card the overlay shows in the middle of a display: why something cannot work, and the keys that help.
nonisolated struct RulerNotice: Equatable, Sendable {
    let symbol: String
    let title: String
    let message: String
    let keys: [KeyHint]

    static let screenRecordingNeeded = RulerNotice(
        symbol: "rectangle.dashed.badge.record",
        title: "Dimensions needs Screen Recording",
        message: """
        To find edges, Screen Ruler reads a still picture of the screen, which macOS allows only with Screen & System \
        Audio Recording. Measure Area and Guides work without it.
        """,
        keys: [KeyHint(key: "↩", label: "Open System Settings"), KeyHint(key: "⇥", label: "Another mode")]
    )

    static func readFailed(_ reason: String) -> RulerNotice {
        RulerNotice(
            symbol: "exclamationmark.triangle",
            title: "Screen Ruler could not read the screen",
            message: "\(reason) Measure Area and Guides still work.",
            keys: [KeyHint(key: "⇥", label: "Another mode")]
        )
    }
}
