/// Something the user can trigger from the status menu, a global shortcut, an `oriel://` URL and Settings → Shortcuts,
/// declared once by the feature or tool that owns it (PLAN §6.5). The app wires up every command it is given, so a new
/// tool or capture mode needs no change to the app's own action table.
public struct ToolCommand: Identifiable, Sendable {
    /// The status-menu section a command appears in.
    public enum Group: Int, CaseIterable, Sendable {
        case capture, recording, translation, tools, library
    }

    /// Stable and unique across the app: the shortcut is stored as `shortcuts.<id>` and registered under this name, so
    /// renaming a command loses the user's shortcut.
    public let id: String
    public let title: String
    /// An SF Symbol name.
    public let symbol: String
    public let group: Group
    public let defaultShortcut: KeyCombo?
    /// The path of its `oriel://` URL (`capture/text` for `oriel://capture/text`), if it has one.
    public let route: String?
    /// Whether the status menu lists it; a command that only makes sense as a shortcut leaves it out.
    public let showsInMenu: Bool
    /// The Pro feature it starts, if it needs Oriel Pro (PLAN §19).
    public let proFeature: ProFeature?
    public let perform: @MainActor @Sendable () -> Void

    public init(
        id: String,
        title: String,
        symbol: String,
        group: Group,
        defaultShortcut: KeyCombo? = nil,
        route: String? = nil,
        showsInMenu: Bool = true,
        proFeature: ProFeature? = nil,
        perform: @escaping @MainActor @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.group = group
        self.defaultShortcut = defaultShortcut
        self.route = route
        self.showsInMenu = showsInMenu
        self.proFeature = proFeature
        self.perform = perform
    }

    /// The same command, asking `access` first when it starts a Pro feature: what the app wires to its menu items,
    /// shortcuts, URLs and App Intents, so none of them can start a locked feature.
    public func gated(by access: ProAccess) -> ToolCommand {
        guard let proFeature else { return self }
        let perform = perform
        return ToolCommand(
            id: id, title: title, symbol: symbol, group: group, defaultShortcut: defaultShortcut, route: route,
            showsInMenu: showsInMenu, proFeature: proFeature
        ) {
            if access.check(proFeature) {
                perform()
            }
        }
    }

    /// Where the user's shortcut for the command is kept.
    public var shortcutKey: SettingKey<KeyCombo?> {
        SettingKey("shortcuts.\(id)", default: defaultShortcut)
    }
}
