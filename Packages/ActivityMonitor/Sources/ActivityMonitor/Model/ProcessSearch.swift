import Foundation

/// The search field: every word must appear, ignoring case and accents, in the process's name, short name, user,
/// bundle ID or path; a number also matches pids that start with it.
nonisolated enum ProcessSearch {
    static func terms(in query: String) -> [String] {
        fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The text a process is searched in, folded once and kept by the caller.
    static func haystack(for process: ProcessMetrics) -> String {
        fold([process.name, process.command, process.user, process.app?.bundleID ?? "", process.path ?? ""].joined(separator: "\n"))
    }

    static func matches(_ process: ProcessMetrics, haystack: String, terms: [String]) -> Bool {
        let pid = String(process.pid)
        return terms.allSatisfy { term in
            haystack.contains(term) || (term.allSatisfy(\.isNumber) && pid.hasPrefix(term))
        }
    }

    static func matches(_ process: ProcessMetrics, terms: [String]) -> Bool {
        terms.isEmpty || matches(process, haystack: haystack(for: process), terms: terms)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
