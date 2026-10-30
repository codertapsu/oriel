/// One way to get a folder's space back, with what it frees (PLAN §7.10 item 19). Everything removed goes to the Trash,
/// through the usual confirmation, with Undo; nothing is deleted at once.
nonisolated struct CleanupMethod: Sendable, Equatable, Identifiable {
    enum Action: Sendable, Equatable {
        /// Move the folder to the Trash.
        case trashFolder
        /// Move what it holds to the Trash; the folder stays, as the apps that use it expect.
        case trashContents
        /// Move these items, inside it, to the Trash.
        case trashItems([String])
        /// Run the tool's own command.
        case run(CleanupCommand)
        /// Copy a command for Terminal: a tool Oriel does not run itself.
        case copyCommand(String)
        /// Do it in the app that owns it.
        case openApp(bundleID: String, name: String)
        /// Old Files for this folder, to choose what goes.
        case showOldFiles
        /// Show it in Finder; nothing else.
        case reveal
    }

    var id: String
    var title: String
    var detail: String
    var action: Action
    /// What it frees, when Oriel can tell.
    var bytes: Int64?

    /// Whether it moves items to the Trash.
    var trashes: Bool {
        switch action {
        case .trashFolder, .trashContents, .trashItems: true
        case .run, .copyCommand, .openApp, .showOldFiles, .reveal: false
        }
    }

    static func trashFolder(_ facts: CleanupFacts, detail: String = "The Trash brings it back until you empty it.") -> CleanupMethod {
        CleanupMethod(id: "trashFolder", title: "Move the folder to the Trash", detail: detail, action: .trashFolder, bytes: facts.bytes)
    }

    static func trashContents(
        _ facts: CleanupFacts,
        detail: String = "The folder stays, empty, for the apps that use it."
    ) -> CleanupMethod {
        CleanupMethod(
            id: "trashContents", title: "Move what it holds to the Trash", detail: detail, action: .trashContents, bytes: facts.bytes
        )
    }

    /// Nil when there is nothing to move.
    static func trashItems(_ items: [CleanupFacts.Child], id: String, title: String, detail: String) -> CleanupMethod? {
        guard !items.isEmpty else { return nil }
        return CleanupMethod(
            id: id, title: title, detail: detail, action: .trashItems(items.map(\.path)), bytes: items.reduce(0) { $0 + $1.bytes }
        )
    }

    static func run(_ command: CleanupCommand, title: String, detail: String, bytes: Int64?) -> CleanupMethod {
        CleanupMethod(id: "run.\(command.rawValue)", title: title, detail: detail, action: .run(command), bytes: bytes)
    }

    static func copy(_ command: String, title: String, detail: String) -> CleanupMethod {
        CleanupMethod(id: "copy", title: title, detail: detail, action: .copyCommand(command), bytes: nil)
    }

    static func openApp(_ bundleID: String, name: String, detail: String) -> CleanupMethod {
        CleanupMethod(
            id: "open.\(bundleID)",
            title: "Clean it up in \(name)",
            detail: detail,
            action: .openApp(bundleID: bundleID, name: name)
        )
    }

    static let showOldFiles = CleanupMethod(
        id: "oldFiles", title: "Choose what goes in Old Files", detail: "Lists what you have not used for a long time, largest first.",
        action: .showOldFiles
    )

    static let reveal = CleanupMethod(
        id: "reveal", title: "Show it in Finder", detail: "Look inside, and decide for yourself.", action: .reveal
    )
}
