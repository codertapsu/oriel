import AppKit

/// The window's colours: system colours for the graphs' series, as Activity Monitor uses them (blue for user time,
/// reads and data in; red for system time, writes and data out), and a warning orange for heavy use that stays
/// readable as text on a light background.
enum ActivityColors {
    static let user = NSColor.systemBlue
    static let system = NSColor.systemRed
    static let read = NSColor.systemBlue
    static let written = NSColor.systemRed
    static let received = NSColor.systemBlue
    static let sent = NSColor.systemRed
    static let gpu = NSColor.systemGreen
    static let power = NSColor.systemOrange

    /// Orange text: darker in light mode, where the system orange is too pale to read.
    static let heavy = NSColor(name: "ActivityMonitor.heavy") { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) == nil
            ? NSColor(srgbRed: 0.76, green: 0.33, blue: 0.0, alpha: 1)
            : .systemOrange
    }

    static func pressure(_ level: MemoryPressure.Level) -> NSColor {
        switch level {
        case .normal: .systemGreen
        case .warning: .systemYellow
        case .critical: .systemRed
        }
    }
}
