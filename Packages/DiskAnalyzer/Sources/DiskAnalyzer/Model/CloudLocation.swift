import Foundation

/// A cloud storage folder on this Mac: iCloud Drive (`~/Library/Mobile Documents`), or a File Provider domain in
/// `~/Library/CloudStorage` (Google Drive, Dropbox, OneDrive, Box…). macOS shows how much of it is downloaded, not the
/// plan's size: no public API reports a provider's quota, so Oriel links to the provider's own storage page.
nonisolated struct CloudLocation: Sendable, Equatable, Identifiable {
    enum Provider: String, Sendable, CaseIterable {
        case iCloud, googleDrive, dropbox, oneDrive, box, other

        var title: String {
            switch self {
            case .iCloud: "iCloud Drive"
            case .googleDrive: "Google Drive"
            case .dropbox: "Dropbox"
            case .oneDrive: "OneDrive"
            case .box: "Box"
            case .other: "Cloud storage"
            }
        }

        var symbol: String {
            self == .iCloud ? "icloud" : "cloud"
        }

        /// Where the plan and its free space are shown. iCloud's is in System Settings.
        var storagePage: URL? {
            switch self {
            case .iCloud: URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings?iCloud")
            case .googleDrive: URL(string: "https://drive.google.com/settings/storage")
            case .dropbox: URL(string: "https://www.dropbox.com/account/plan")
            case .oneDrive: URL(string: "https://account.microsoft.com/storage")
            case .box: URL(string: "https://app.box.com/account")
            case .other: nil
            }
        }

        /// The provider a `~/Library/CloudStorage` folder name ("GoogleDrive-me@example.com") belongs to.
        static func of(folderName: String) -> Provider {
            let provider = folderName.split(separator: "-", maxSplits: 1).first.map { $0.lowercased() } ?? ""
            if provider.contains("google") {
                return .googleDrive
            }
            if provider.contains("dropbox") {
                return .dropbox
            }
            if provider.contains("onedrive") {
                return .oneDrive
            }
            if provider == "box" {
                return .box
            }
            return .other
        }
    }

    var provider: Provider
    var path: String
    /// The account, when the folder name has one ("me@example.com").
    var account: String?

    var id: String {
        path
    }

    var title: String {
        guard provider != .other else { return (path as NSString).lastPathComponent }
        return provider.title
    }

    /// The `~/Library/CloudStorage` folder `name` inside `cloudStorage`.
    static func fileProvider(folderName name: String, in cloudStorage: String) -> CloudLocation {
        let parts = name.split(separator: "-", maxSplits: 1)
        let account = parts.count == 2 ? String(parts[1]) : nil
        return CloudLocation(provider: .of(folderName: name), path: cloudStorage + "/" + name, account: account)
    }
}
