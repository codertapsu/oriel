import Foundation

/// Finds the cloud storage folders on this Mac by their names alone; nothing inside them is read until the user scans
/// one, which is when macOS may ask whether Oriel may see files managed by that provider.
nonisolated enum CloudLocator {
    static func locations(home: String, fileManager: FileManager = .default) -> [CloudLocation] {
        var locations: [CloudLocation] = []
        let iCloud = home + "/Library/Mobile Documents/com~apple~CloudDocs"
        if fileManager.fileExists(atPath: iCloud) {
            locations.append(CloudLocation(provider: .iCloud, path: iCloud, account: nil))
        }
        let cloudStorage = home + "/Library/CloudStorage"
        let names = (try? fileManager.contentsOfDirectory(atPath: cloudStorage)) ?? []
        for name in names.sorted() where !name.hasPrefix(".") {
            var isFolder: ObjCBool = false
            guard fileManager.fileExists(atPath: cloudStorage + "/" + name, isDirectory: &isFolder), isFolder.boolValue else { continue }
            locations.append(CloudLocation.fileProvider(folderName: name, in: cloudStorage))
        }
        return locations
    }
}
