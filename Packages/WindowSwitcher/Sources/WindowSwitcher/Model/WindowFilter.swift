import CoreGraphics
import OrielCore

/// A shortcut's window filter (PLAN §7.1.4): apps all/active, Spaces all/current, screens all/current,
/// minimized and hidden windows included or excluded. Pure, so it is table-tested.
nonisolated struct WindowFilter: Codable, Sendable, Hashable {
    nonisolated enum Apps: String, Codable, Sendable, CaseIterable {
        case all
        /// Only the windows of the app that was frontmost when the switcher opened.
        case active
    }

    nonisolated enum Scope: String, Codable, Sendable, CaseIterable {
        case all
        /// Spaces: the Spaces visible right now. Screens: the screen under the pointer.
        case current
    }

    nonisolated enum Inclusion: String, Codable, Sendable, CaseIterable {
        case include
        case exclude
    }

    var apps: Apps
    var spaces: Scope
    var screens: Scope
    var minimized: Inclusion
    var hidden: Inclusion

    init(
        apps: Apps = .all,
        spaces: Scope = .all,
        screens: Scope = .all,
        minimized: Inclusion = .include,
        hidden: Inclusion = .include
    ) {
        self.apps = apps
        self.spaces = spaces
        self.screens = screens
        self.minimized = minimized
        self.hidden = hidden
    }

    /// Tolerates settings written by older builds: a missing field keeps its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apps = try container.decodeIfPresent(Apps.self, forKey: .apps) ?? .all
        spaces = try container.decodeIfPresent(Scope.self, forKey: .spaces) ?? .all
        screens = try container.decodeIfPresent(Scope.self, forKey: .screens) ?? .all
        minimized = try container.decodeIfPresent(Inclusion.self, forKey: .minimized) ?? .include
        hidden = try container.decodeIfPresent(Inclusion.self, forKey: .hidden) ?? .include
    }

    /// The entries that pass, in their original order.
    func apply(to entries: [WindowEntry], context: FilterContext) -> [WindowEntry] {
        entries.filter { accepts($0.info, context: context) }
    }

    func accepts(_ window: WindowInfo, context: FilterContext) -> Bool {
        if apps == .active, window.pid != context.activePID {
            return false
        }
        if spaces == .current, !window.isOnCurrentSpace {
            return false
        }
        if screens == .current, let screen = context.screenDisplayID, context.displayID(of: window) != screen {
            return false
        }
        if minimized == .exclude, window.isMinimized {
            return false
        }
        if hidden == .exclude, window.isHidden {
            return false
        }
        return true
    }
}
