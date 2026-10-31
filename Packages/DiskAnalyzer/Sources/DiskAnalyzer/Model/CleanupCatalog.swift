import Foundation

/// The folders Oriel knows (PLAN §7.10 item 19): macOS's and Apple's apps' here, developer tools' and projects' in the
/// extensions. The first rule that matches speaks for the folder, so the general ones (any app's cache or logs) come last.
nonisolated enum CleanupCatalog {
    static let rules: [CleanupRule] = apple + developerTools + projects + general

    static let xcode = "com.apple.dt.Xcode"
    static let finder = "com.apple.finder"

    static let apple: [CleanupRule] = [
        CleanupRule(
            id: "systemSimulatorCaches",
            matches: [.path("/Library/Developer/CoreSimulator/Caches"), .path("/Library/Developer/CoreSimulator/Caches/*")],
            verdict: .safe,
            summary: "The simulators' shared caches (dyld), one set per macOS build and simulator runtime. CoreSimulator builds "
                + "them again when a simulator starts.",
            afterwards: "The next start of each simulator takes a few minutes longer.",
            methods: { facts in
                [
                    .run(
                        .removeSimulatorCaches, title: "Have CoreSimulator remove them",
                        detail: "Runs `\(CleanupCommand.removeSimulatorCaches.commandLine)`. They belong to macOS's root account, "
                            + "so this is the way to remove them.",
                        bytes: facts.bytes
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "simulatorRuntimes",
            matches: ["Images", "Volumes", "Cryptex"].map { .path("/Library/Developer/CoreSimulator/\($0)") },
            verdict: .careful,
            summary: "Simulator runtimes, several gigabytes each, which Xcode downloaded.",
            afterwards: "Xcode downloads a runtime again when you need it.",
            methods: { _ in
                [
                    .openApp(
                        xcode,
                        name: "Xcode",
                        detail: "Settings → Components lists the runtimes; delete the ones you no longer test on."
                    ),
                    .copy(
                        "xcrun simctl runtime delete --notUsedSinceDays 90",
                        title: "Copy the command that deletes runtimes unused for 90 days",
                        detail: "Run it in Terminal."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "derivedData",
            matches: [.path("~/Library/Developer/Xcode/DerivedData"), .path("~/Library/Developer/Xcode/DerivedData/*")],
            verdict: .safe,
            summary: "Xcode's build products and indexes, a folder per project.",
            afterwards: "The next build of each project takes longer, and Xcode indexes it again.",
            apps: [xcode],
            methods: { facts in
                [unused(facts, days: 30, noun: "projects"), .trashContents(facts, detail: "Every project's; the folder stays.")]
                    .compactMap(\.self)
            }
        ),
        CleanupRule(
            id: "archives",
            matches: [.path("~/Library/Developer/Xcode/Archives")],
            verdict: .keep,
            summary: "Xcode's archived builds. The symbols of the versions you shipped explain their crash reports.",
            methods: { _ in
                [
                    .openApp(xcode, name: "Xcode", detail: "Window → Organizer lists the archives; delete those of versions nobody uses."),
                    .reveal,
                ]
            }
        ),
        CleanupRule(
            id: "deviceSupport",
            matches: [.path("~/Library/Developer/Xcode/* DeviceSupport")],
            verdict: .safe,
            summary: "Symbols Xcode copied from the devices you debugged on, a folder per device and OS version.",
            afterwards: "Xcode copies them again when you connect a device with that version.",
            methods: { facts in
                [unused(facts, days: 90, noun: "versions"), .trashContents(facts)].compactMap(\.self)
            }
        ),
        CleanupRule(
            id: "previews",
            matches: [.path("~/Library/Developer/Xcode/UserData/Previews")],
            verdict: .safe,
            summary: "The simulators SwiftUI previews run in.",
            afterwards: "Xcode makes them again for the next preview.",
            apps: [xcode],
            methods: contents
        ),
        CleanupRule(
            id: "simulators",
            matches: [.path("~/Library/Developer/CoreSimulator/Devices")],
            verdict: .careful,
            summary: "Simulated devices, with the apps and data you put on them.",
            methods: { _ in
                [
                    .run(
                        .deleteUnavailableSimulators, title: "Delete the unavailable simulators",
                        detail: "Those whose runtime is no longer installed; Xcode never shows them.", bytes: nil
                    ),
                    .openApp(xcode, name: "Xcode", detail: "Window → Devices and Simulators deletes the ones you no longer use."),
                ]
            }
        ),
        CleanupRule(
            id: "simulatorCaches",
            matches: [.path("~/Library/Developer/CoreSimulator/Caches")],
            verdict: .safe,
            summary: "Caches of the simulator runtimes.",
            afterwards: "They are made again when a simulator starts.",
            methods: contents
        ),
        CleanupRule(
            id: "deviceBackups",
            matches: [.path("~/Library/Application Support/MobileSync/Backup")],
            verdict: .keep,
            summary: "Backups Finder made of your iPhone and iPad: for some of them, the only copy.",
            methods: { _ in
                [.openApp(finder, name: "Finder", detail: "Select the device in the sidebar, then Manage Backups."), .reveal]
            }
        ),
        CleanupRule(
            id: "softwareUpdates",
            matches: [.path("~/Library/iTunes/iPhone Software Updates"), .path("~/Library/iTunes/iPad Software Updates")],
            verdict: .safe,
            summary: "Update files Finder downloaded for your devices.",
            afterwards: "Finder downloads them again when a device needs one.",
            methods: contents
        ),
        CleanupRule(
            id: "mailDownloads",
            matches: [.path("~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads")],
            verdict: .safe,
            summary: "Attachments you opened from Mail. The originals stay in your messages.",
            apps: ["com.apple.mail"],
            methods: contents
        ),
        CleanupRule(
            id: "mail",
            matches: [.path("~/Library/Mail"), .path("~/Library/Containers/com.apple.mail")],
            verdict: .keep,
            summary: "Your mail and its attachments.",
            methods: { _ in
                [.openApp("com.apple.mail", name: "Mail", detail: "Delete messages, then Mailbox → Erase Deleted Items.")]
            }
        ),
        CleanupRule(
            id: "messages",
            matches: [.path("~/Library/Messages")],
            verdict: .keep,
            summary: "Your messages and their attachments.",
            methods: { _ in
                [.openApp("com.apple.MobileSMS", name: "Messages", detail: "Delete conversations, or set Keep Messages in Settings.")]
            }
        ),
        CleanupRule(
            id: "photos",
            matches: [.path("~/Pictures/*.photoslibrary")],
            verdict: .keep,
            summary: "Your Photos library.",
            methods: { _ in
                [.openApp("com.apple.Photos", name: "Photos", detail: "Delete photos there, then empty Recently Deleted.")]
            }
        ),
        CleanupRule(
            id: "cloud",
            matches: ["Mobile Documents", "CloudStorage"].flatMap { [.path("~/Library/\($0)"), .path("~/Library/\($0)/*")] },
            verdict: .keep,
            summary: "Cloud storage: removing something here removes it from the cloud and your other devices too.",
            methods: { _ in [.reveal] }
        ),
        CleanupRule(
            id: "downloads",
            matches: [.path("~/Downloads")],
            verdict: .review,
            summary: "What you downloaded: your own files, and installers that are usually not needed once their app is installed.",
            methods: { facts in [installers(facts), .showOldFiles, .reveal].compactMap(\.self) }
        ),
        CleanupRule(
            id: "trash",
            matches: [.path("~/.Trash")],
            verdict: .careful,
            summary: "The Trash: what you already moved there, which takes space until you empty it.",
            methods: { _ in [.openApp(finder, name: "Finder", detail: "Finder → Empty Trash. What is in it is then gone for good.")] }
        ),
        CleanupRule(
            id: "userTemporary",
            matches: [.path("/private/var/folders"), .path("/var/folders")],
            verdict: .keep,
            summary: "macOS's temporary files and caches, a folder per user, which macOS clears by itself; restarting frees some.",
            methods: { _ in [.reveal] }
        ),
        CleanupRule(
            id: "systemTemporary",
            matches: ["/private/tmp", "/tmp", "/private/var/tmp", "/var/tmp"].map { .path($0) },
            verdict: .keep,
            summary: "The system's temporary folder: running programs keep their sockets, locks and working files here, and "
                + "macOS empties /tmp when the Mac restarts.",
            methods: { _ in [.reveal] }
        ),
        CleanupRule(
            id: "swap",
            matches: [.path("/private/var/vm"), .path("/System/Volumes/VM")],
            verdict: .keep,
            summary: "macOS's swap files and sleep image, which macOS frees by itself when memory allows.",
            methods: { _ in [] }
        ),
        CleanupRule(
            id: "sharedCaches",
            matches: [.path("/Library/Caches")],
            verdict: .careful,
            summary: "Caches every user's apps share, kept by macOS and installers.",
            methods: { _ in [.reveal] }
        ),
    ]

    /// Any app's cache and logs, after every rule for a particular one.
    static let general: [CleanupRule] = [
        CleanupRule(
            id: "caches",
            matches: [.path("~/Library/Caches")],
            verdict: .safe,
            summary: "Apps' caches: what apps keep to go faster, which they download or rebuild when it is missing.",
            afterwards: "Apps are slower the first time they need what was removed.",
            methods: { facts in [.trashContents(facts, detail: "Quit your apps first. The folder stays.")] }
        ),
        CleanupRule(
            id: "appCache",
            matches: [
                .path("~/Library/Caches/*"), .path("~/Library/Containers/*/Data/Library/Caches"),
                .path("~/Library/Containers/*/Data/tmp"),
            ],
            verdict: .safe,
            summary: "An app's cache: what it keeps to go faster, which it downloads or rebuilds when it is missing.",
            afterwards: "The app is slower the first time it needs what was removed.",
            methods: contents
        ),
        CleanupRule(
            id: "logs",
            matches: [.path("~/Library/Logs"), .path("~/Library/Logs/*")],
            verdict: .safe,
            summary: "Logs: what apps wrote about what they did, for troubleshooting.",
            methods: contents
        ),
    ]

    // MARK: Methods the rules share

    /// Disk images and installer packages, as Space Hogs finds them in Downloads.
    static let installerExtensions: Set = ["dmg", "pkg", "mpkg", "iso", "xip"]

    static let contents: @Sendable (CleanupFacts) -> [CleanupMethod] = { [.trashContents($0)] }
    static let folder: @Sendable (CleanupFacts) -> [CleanupMethod] = { [.trashFolder($0)] }

    /// What it holds that was not used for `days` days, those in use left out; nil when that is nothing, or everything,
    /// which moving all of it says better.
    static func unused(_ facts: CleanupFacts, days: Int, noun: String) -> CleanupMethod? {
        let cutoff = facts.now.addingTimeInterval(-Double(days) * 86400)
        let busy = facts.busyItems
        let items = facts.children.filter { child in
            !busy.contains(child.name) && child.lastUsed.map { $0 < cutoff } == true
        }
        guard items.count < facts.children.count else { return nil }
        return .trashItems(
            items, id: "unused\(days)", title: "Move the \(noun) not used for \(DiskFormat.days(days)) to the Trash",
            detail: "\(DiskFormat.count(items.count, "item")); the ones used since stay."
        )
    }

    /// The disk images and installer packages it holds, those in use left out; nil when there is none.
    static func installers(_ facts: CleanupFacts) -> CleanupMethod? {
        let busy = facts.busyItems
        let items = facts.children.filter { child in
            !child.isFolder && !busy.contains(child.name)
                && FileCategory.fileExtension(of: child.name).map(installerExtensions.contains) == true
        }
        return .trashItems(
            items, id: "installers", title: "Move the installers to the Trash",
            detail: "\(DiskFormat.count(items.count, "disk image or package", plural: "disk images and packages")). Once "
                + "their app is installed, they are usually no longer needed."
        )
    }

    /// For the folders named with a version (`9.1.0`, `AndroidStudio2025.3.2`, `gradle-8.5-bin`), every version but the
    /// newest of each name; nil when there is none.
    static func olderVersions(_ facts: CleanupFacts, of thing: String) -> CleanupMethod? {
        // Folders only: tools keep a folder per version, while files named with one are what the user downloaded.
        let folders = facts.children.filter(\.isFolder)
        let busy = facts.busyItems
        let older = VersionedNames.older(among: folders).filter { !busy.contains($0.name) }
        let kept = VersionedNames.newest(among: folders).map(\.name)
        return .trashItems(
            older, id: "olderVersions", title: "Move the \(thing) of older versions to the Trash",
            detail: older.map(\.name).sorted()
                .joined(separator: ", ") + (kept.isEmpty ? "" : ". \(kept.sorted().joined(separator: ", ")) stays.")
        )
    }
}
