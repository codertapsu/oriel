/// A kind of thing that often takes a lot of space without the user knowing, with what it is, whether it comes back
/// by itself, and the one safe action offered for it. Space Hogs only informs; nothing is removed without a
/// confirmation that lists the items and their size.
nonisolated struct SpaceHog: Sendable, Equatable, Identifiable {
    enum Location: Sendable, Equatable {
        /// A folder, relative to the home folder; what it holds is the hog.
        case folder(String)
        /// Every folder with this name in the current scan (`node_modules`).
        case foldersNamed(String)
        /// The files with these extensions directly in a folder relative to the home folder.
        case files(in: String, extensions: Set<String>)
    }

    enum Action: Sendable, Equatable {
        /// Move what the folder holds to the Trash; the folder stays.
        case trashContents
        /// Move the items found to the Trash.
        case trashItems
        /// Show it in Finder; the user decides.
        case reveal
        /// `xcrun simctl delete unavailable`: simulators for runtimes no longer installed.
        case deleteUnavailableSimulators
        case openTrash
    }

    var id: String
    var title: String
    var detail: String
    var symbol: String
    var location: Location
    var action: Action
    /// Whether it is rebuilt or downloaded again when needed, so removing it loses nothing.
    var isRebuilt: Bool
    /// Whether reading it needs Full Disk Access.
    var needsFullDiskAccess = false

    /// The absolute folder it is in or is, for a home folder `home`; nil for hogs found by name.
    func folder(home: String) -> String? {
        switch location {
        case let .folder(relative), let .files(in: relative, _): home + "/" + relative
        case .foldersNamed: nil
        }
    }
}
