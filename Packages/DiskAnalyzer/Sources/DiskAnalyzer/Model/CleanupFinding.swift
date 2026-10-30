/// Something Oriel found about a folder, for or against cleaning it up (PLAN §7.10 item 19).
nonisolated struct CleanupFinding: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// For: it comes back by itself.
        case good
        case note
        /// Do something first.
        case warning
        /// Against: something would be lost.
        case stop
    }

    var kind: Kind
    var text: String

    init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }

    /// An SF Symbol.
    var symbol: String {
        switch kind {
        case .good: "checkmark.circle"
        case .note: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .stop: "xmark.octagon"
        }
    }
}
