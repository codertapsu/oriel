import AppKit

/// The apps a folder's path names (PLAN §7.10 item 19): by bundle ID, as caches, containers and preferences are named
/// (`com.spotify.client`, an extension's `com.example.App.Share`), or by name, as Application Support's folders are
/// (`Slack`, `Google/Chrome`). A bundle ID no installed app has, other than macOS's own (`com.apple.…`), is what is left
/// of a removed app.
enum CleanupApps {
    static func named(
        by path: String,
        home: String,
        running: [CleanupFacts.App]
    ) -> (apps: [CleanupFacts.App], missing: [String]) {
        let library = home + "/Library/"
        guard path.hasPrefix(library) else { return ([], []) }
        let names = path.dropFirst(library.count).split(separator: "/").map(String.init)
        guard names.count >= 2 else { return ([], []) }
        let candidates = Array(names.dropFirst().prefix(2))
        var apps: [CleanupFacts.App] = []
        var missing: [String] = []
        for (offset, name) in candidates.enumerated() {
            if looksLikeBundleID(name) {
                if let app = app(bundleID: name, running: running) {
                    apps.append(app)
                } else if names[0] != "Group Containers", !name.hasPrefix("com.apple.") {
                    missing.append(name)
                }
            } else {
                // A vendor's folder, then the app's inside it: Google, then Chrome, is Google Chrome.
                let joined = offset > 0 ? candidates[offset - 1] + " " + name : nil
                let found = app(named: name, home: home, running: running)
                    ?? joined.flatMap { app(named: $0, home: home, running: running) }
                if let found {
                    apps.append(found)
                }
            }
        }
        var seen = Set<String>()
        return (apps.filter { seen.insert($0.bundleID).inserted }, missing)
    }

    /// Three or more parts joined by dots, starting with a letter: `com.example.app`.
    nonisolated static func looksLikeBundleID(_ name: String) -> Bool {
        name.range(of: #"^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9_-]+){2,}$"#, options: .regularExpression) != nil
    }

    /// The app with this bundle ID, or with the longest bundle ID it starts with (an extension's app).
    private static func app(bundleID: String, running: [CleanupFacts.App]) -> CleanupFacts.App? {
        var parts = bundleID.split(separator: ".").map(String.init)
        while parts.count >= 3 {
            let id = parts.joined(separator: ".")
            if let app = running.first(where: { $0.bundleID == id }) {
                return app
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return CleanupFacts.App(bundleID: id, name: displayName(of: url), isRunning: false)
            }
            parts.removeLast()
        }
        return nil
    }

    private static func app(named name: String, home: String, running: [CleanupFacts.App]) -> CleanupFacts.App? {
        if let app = running.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return app
        }
        for folder in ["/Applications", home + "/Applications"] {
            if let bundle = Bundle(path: folder + "/" + name + ".app"), let id = bundle.bundleIdentifier {
                return CleanupFacts.App(bundleID: id, name: name, isRunning: false)
            }
        }
        return nil
    }

    private static func displayName(of url: URL) -> String {
        FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
