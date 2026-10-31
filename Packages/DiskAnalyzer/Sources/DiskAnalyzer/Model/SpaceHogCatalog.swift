/// The space hogs Oriel knows, in the order they are listed.
nonisolated enum SpaceHogCatalog {
    /// The hogs a change at `paths` may have resized: those whose folder is one of them, holds one or is inside one, and
    /// those found by name in the scan, which its edits change.
    static func touched(by paths: [String], home: String) -> [SpaceHog] {
        all.filter { hog in
            guard let folder = hog.folder(home: home) else { return true }
            return paths.contains { $0 == folder || $0.hasPrefix(folder + "/") || folder.hasPrefix($0 + "/") }
        }
    }

    static let all: [SpaceHog] = [
        SpaceHog(
            id: "caches", title: "App caches",
            detail: "Data apps keep to go faster and download or rebuild when it is missing. Quit apps before clearing them.",
            symbol: "internaldrive.fill", location: .folder("Library/Caches"), action: .trashContents, isRebuilt: true
        ),
        SpaceHog(
            id: "logs", title: "Logs",
            detail: "Records apps write about what they did. Useful for troubleshooting, safe to remove.",
            symbol: "doc.text.magnifyingglass", location: .folder("Library/Logs"), action: .trashContents, isRebuilt: true
        ),
        SpaceHog(
            id: "derivedData", title: "Xcode DerivedData",
            detail: "Build products and indexes. Xcode rebuilds them; the next build takes longer.",
            symbol: "hammer", location: .folder("Library/Developer/Xcode/DerivedData"), action: .trashContents, isRebuilt: true
        ),
        SpaceHog(
            id: "archives", title: "Xcode Archives",
            detail: "Archived builds. Keep the ones of versions you shipped: their symbols explain crash reports.",
            symbol: "archivebox", location: .folder("Library/Developer/Xcode/Archives"), action: .reveal, isRebuilt: false
        ),
        SpaceHog(
            id: "deviceSupport", title: "Device support files",
            detail: "Symbols of the devices you debugged on. Xcode copies them again when you connect a device.",
            symbol: "iphone", location: .folder("Library/Developer/Xcode/iOS DeviceSupport"), action: .trashContents,
            isRebuilt: true
        ),
        SpaceHog(
            id: "simulators", title: "Simulators",
            detail: "Simulated devices and their apps. Unavailable ones belong to runtimes that are no longer installed.",
            symbol: "ipad.and.iphone", location: .folder("Library/Developer/CoreSimulator/Devices"),
            action: .deleteUnavailableSimulators, isRebuilt: false
        ),
        SpaceHog(
            id: "simulatorCaches", title: "Simulator caches",
            detail: "Caches of the simulator runtimes, rebuilt when a simulator starts.",
            symbol: "internaldrive", location: .folder("Library/Developer/CoreSimulator/Caches"), action: .trashContents,
            isRebuilt: true
        ),
        SpaceHog(
            id: "deviceBackups", title: "iPhone and iPad backups",
            detail: "Backups Finder made of your devices. Manage them in Finder: select the device, then Manage Backups.",
            symbol: "externaldrive.badge.timemachine", location: .folder("Library/Application Support/MobileSync/Backup"),
            action: .reveal, isRebuilt: false, needsFullDiskAccess: true
        ),
        SpaceHog(
            id: "softwareUpdates", title: "iOS software updates",
            detail: "Update files Finder downloaded for your devices. It downloads them again when needed.",
            symbol: "arrow.down.circle", location: .folder("Library/iTunes/iPhone Software Updates"), action: .trashContents,
            isRebuilt: true
        ),
        SpaceHog(
            id: "mailDownloads", title: "Mail downloads",
            detail: "Attachments you opened in Mail. The originals stay in your messages.",
            symbol: "envelope", location: .folder("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
            action: .trashContents, isRebuilt: true, needsFullDiskAccess: true
        ),
        SpaceHog(
            id: "installers", title: "Installers in Downloads",
            detail: "Disk images and installer packages. Once the app is installed, they are usually no longer needed.",
            symbol: "shippingbox", location: .files(in: "Downloads", extensions: CleanupCatalog.installerExtensions),
            action: .trashItems, isRebuilt: false
        ),
        SpaceHog(
            id: "nodeModules", title: "node_modules folders",
            detail: "JavaScript packages of your projects. `npm install` brings them back. Found in the current scan.",
            symbol: "shippingbox.circle", location: .foldersNamed("node_modules"), action: .trashItems, isRebuilt: true
        ),
        SpaceHog(
            id: "swiftBuild", title: "Swift package builds",
            detail: "The .build folders of Swift packages, rebuilt on the next build. Found in the current scan.",
            symbol: "swift", location: .foldersNamed(".build"), action: .trashItems, isRebuilt: true
        ),
        SpaceHog(
            id: "npmCache", title: "npm cache",
            detail: "Packages npm downloaded before. It downloads them again when needed.",
            symbol: "arrow.down.app", location: .folder(".npm/_cacache"), action: .trashContents, isRebuilt: true
        ),
        SpaceHog(
            id: "gradleCache", title: "Gradle caches",
            detail: "Dependencies and build caches of Gradle projects, downloaded again when needed.",
            symbol: "cube.box", location: .folder(".gradle/caches"), action: .trashContents, isRebuilt: true
        ),
        SpaceHog(
            id: "trash", title: "Trash",
            detail: "Items you moved to the Trash still take space until you empty it in Finder.",
            symbol: "trash", location: .folder(".Trash"), action: .openTrash, isRebuilt: false
        ),
    ]
}
