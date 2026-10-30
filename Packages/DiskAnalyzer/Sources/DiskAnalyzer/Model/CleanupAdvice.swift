/// What Clean Up says about a folder (PLAN §7.10 item 19): how safe it is, what it is, what Oriel found for and against,
/// and the ways to get its space back, the recommended one first.
nonisolated struct CleanupAdvice: Sendable, Equatable {
    var verdict: CleanupVerdict
    /// What it is.
    var summary: String
    /// What happens once it is gone.
    var afterwards: String?
    var findings: [CleanupFinding]
    var methods: [CleanupMethod]
    /// The catalog's rule that knew the folder; nil when Oriel judged by its place, name and contents.
    var ruleID: String?
    /// Running apps to quit before anything goes.
    var appsToQuit: [CleanupFacts.App] = []

    /// Whether Oriel's catalog knows the folder.
    var isKnown: Bool {
        ruleID != nil
    }

    /// Makes it at least as cautious as `verdict`, never less.
    mutating func raise(to verdict: CleanupVerdict) {
        self.verdict = max(self.verdict, verdict)
    }
}
