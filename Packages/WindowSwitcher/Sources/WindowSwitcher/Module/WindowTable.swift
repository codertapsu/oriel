import OrielCore

/// The human-readable output of `oriel windows list`: one window per row, columns aligned. Pure.
nonisolated enum WindowTable {
    static let appWidth = 24
    static let titleWidth = 60

    static func render(_ windows: [WindowInfo]) -> String {
        guard !windows.isEmpty else { return "No windows." }
        let rows = [["ID", "APP", "TITLE", "STATE"]] + windows.map { window in
            [String(window.id), truncate(window.appName, to: appWidth), truncate(window.title, to: titleWidth), state(of: window)]
        }
        let widths = (0 ..< 3).map { column in rows.map { $0[column].count }.max() ?? 0 }
        return rows
            .map { row in
                let padded = (0 ..< 3).map { pad(row[$0], to: widths[$0]) } + [row[3]]
                return padded.joined(separator: "  ").trimmingTrailingSpaces()
            }
            .joined(separator: "\n")
    }

    /// "minimized, Space 2", as the badges say it.
    static func state(of window: WindowInfo) -> String {
        WindowBadge.badges(for: window).map(\.spokenLabel).joined(separator: ", ")
    }

    static func truncate(_ text: String, to width: Int) -> String {
        let flat = text.replacing("\n", with: " ").replacing("\t", with: " ")
        return flat.count > width ? String(flat.prefix(width - 1)) + "…" : flat
    }

    private static func pad(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(width - text.count, 0))
    }
}

private nonisolated extension String {
    func trimmingTrailingSpaces() -> String {
        var copy = self
        while copy.last == " " {
            copy.removeLast()
        }
        return copy
    }
}
