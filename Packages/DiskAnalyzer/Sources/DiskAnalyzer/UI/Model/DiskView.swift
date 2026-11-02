import OrielCore

/// The views of a scan, in the order of the view switcher (⌘1–⌘8).
nonisolated enum DiskView: String, CaseIterable, Sendable {
    case sunburst, treemap, list, biggest, old, duplicates, types, hogs

    /// The Pro feature the view is, if it needs Oriel Pro (PLAN §19).
    var proFeature: ProFeature? {
        switch self {
        case .old: .oldFiles
        case .duplicates: .duplicates
        default: nil
        }
    }

    var title: String {
        switch self {
        case .sunburst: "Sunburst"
        case .treemap: "Treemap"
        case .list: "List"
        case .biggest: "Biggest Files"
        case .old: "Old Files"
        case .duplicates: "Duplicates"
        case .types: "File Types"
        case .hogs: "Space Hogs"
        }
    }

    /// A shorter title for a narrow switcher.
    var shortTitle: String {
        switch self {
        case .biggest: "Biggest"
        case .old: "Old"
        case .types: "Types"
        case .hogs: "Hogs"
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .sunburst: "chart.pie"
        case .treemap: "square.grid.3x1.below.line.grid.1x2"
        case .list: "list.bullet.indent"
        case .biggest: "arrow.up.doc"
        case .old: "clock.arrow.circlepath"
        case .duplicates: "doc.on.doc"
        case .types: "chart.bar.doc.horizontal"
        case .hogs: "exclamationmark.triangle"
        }
    }

    /// Whether it shows the current folder's contents, so the breadcrumbs move it.
    var browsesFolders: Bool {
        self == .sunburst || self == .treemap || self == .list
    }
}
