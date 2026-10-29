/// Activity Monitor's "Kind": whether a process runs natively on Apple silicon or as Intel code under Rosetta.
nonisolated enum ProcessKind: String, Sendable, Codable {
    case apple
    case intel

    /// The kernel marks a translated process (`P_TRANSLATED`) for every user, unlike `PROC_PIDARCHINFO`, which it
    /// refuses for other users' processes. On an Intel Mac everything is Intel.
    init(isTranslated: Bool, onAppleSilicon: Bool) {
        self = onAppleSilicon && !isTranslated ? .apple : .intel
    }

    var title: String {
        switch self {
        case .apple: "Apple"
        case .intel: "Intel"
        }
    }
}
