import Darwin
import Foundation

/// Clean Up's judgment of a folder (PLAN §7.10 item 19), from the facts alone, so it is the same every time and every
/// rule is tested. A folder the catalog knows gets the catalog's verdict and methods; any other is judged by its place,
/// its name and what it holds, where a tool's own mark (`CACHEDIR.TAG`, kept out of Time Machine) counts for it. Then
/// what is true now applies to either and can only make it more cautious: Oriel refuses it, it is in the cloud, it holds
/// repositories or mostly personal files, a process has files open in it, its app runs, or only an administrator may
/// remove it. Leftovers inside any folder (older versions' folders, temporary browser profiles, caches) are offered too.
nonisolated enum CleanupAdvisor {
    /// Names apps and tools give their caches.
    static let cacheNames: Set<String> = [
        "Cache", "Caches", "cache", "caches", ".cache", "CachedData", "Code Cache", "GPUCache", "ShaderCache", "GrShaderCache",
        "GraphiteDawnCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "CacheStorage", "ScriptCache",
        "component_crx_cache", "CachedExtensionVSIXs", "CachedProfilesData",
    ]
    static let temporaryNames: Set<String> = ["tmp", "temp", "Temp", ".tmp", "TemporaryItems"]
    static let logNames: Set<String> = ["Logs", "logs", "log"]
    /// The temporary browser profiles that automated tests make for each run (ChromeDriver, Puppeteer, Playwright) and
    /// leave behind when a run ends badly.
    static let temporaryProfilePatterns = [
        "scoped_dir*", ".com.google.Chrome.*", ".org.chromium.Chromium.*", "puppeteer_dev_chrome_profile-*",
        "playwright_chromiumdev_profile-*", "playwright_firefoxdev_profile-*",
    ]
    /// Below this, cleaning up frees little.
    static let smallSize: Int64 = 10_000_000
    static let personalFolders = ["Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music"]
    /// Where apps keep their own data in the Library folder.
    static let appDataFolders: Set = ["Application Support", "Containers", "Group Containers"]

    static func advise(_ facts: CleanupFacts, rules: [CleanupRule] = CleanupCatalog.rules) -> CleanupAdvice {
        var advice: CleanupAdvice
        var ruleApps: [String] = []
        if let rule = rules.first(where: { $0.matches(facts) }) {
            advice = CleanupAdvice(
                verdict: rule.verdict, summary: rule.summary, afterwards: rule.afterwards, findings: [], methods: rule.methods(facts),
                ruleID: rule.id
            )
            ruleApps = rule.apps
        } else {
            advice = judged(facts)
        }
        addLeftovers(facts, to: &advice)
        applyRefusal(facts, to: &advice)
        applyContents(facts, to: &advice)
        applyOwnership(facts, to: &advice)
        applyUse(facts, ruleApps: ruleApps, to: &advice)
        addNotes(facts, to: &advice)
        return advice
    }

    // MARK: Folders the catalog does not know

    private static func judged(_ facts: CleanupFacts) -> CleanupAdvice {
        let names = facts.homeRelativePath.split(separator: "/").map(String.init)
        func advice(_ verdict: CleanupVerdict, _ summary: String, _ methods: [CleanupMethod], afterwards: String? = nil) -> CleanupAdvice {
            CleanupAdvice(verdict: verdict, summary: summary, afterwards: afterwards, findings: [], methods: methods, ruleID: nil)
        }
        let profiles = temporaryProfiles(in: facts)
        if !profiles.isEmpty, profiles.reduce(0, { $0 + $1.bytes }) * 2 >= facts.bytes {
            return advice(
                .safe, "Temporary browser profiles that automated tests (ChromeDriver, Puppeteer, Playwright) made for their runs "
                    + "and left behind.", [], afterwards: "The next run makes a new one."
            )
        }
        if facts.names.contains("Local State") {
            return advice(
                .keep, "A Chromium browser's data (Chrome, Edge, Brave, Arc, or the browser of automated tests): its profiles hold "
                    + "history, passwords, bookmarks and settings.", [.reveal]
            )
        }
        if facts.isTaggedCache || cacheNames.contains(facts.name) || names.dropLast().contains(where: cacheNames.contains) {
            return advice(
                .safe, "A cache: what an app or tool keeps to go faster, which it rebuilds when it is missing.", [.trashContents(facts)],
                afterwards: "Its app is slower the first time it needs what was removed."
            )
        }
        if temporaryNames.contains(facts.name) {
            return advice(.safe, "Temporary files, which their app should have removed.", [.trashContents(facts)])
        }
        if logNames.contains(facts.name) {
            return advice(.safe, "Logs: what an app wrote about what it did, for troubleshooting.", [.trashContents(facts)])
        }
        let isAppData = names.count >= 4 && names[0] == "~" && names[1] == "Library" && appDataFolders.contains(names[2])
        if isAppData {
            return appData(facts)
        }
        if names.count >= 2, names[0] == "~", personalFolders.contains(names[1]) {
            return advice(.review, "Your own files.", [.showOldFiles, .reveal])
        }
        if facts.name.hasSuffix(".app") {
            return advice(
                .careful, "An app. Moving it to the Trash removes it; its settings and caches stay in your Library folder.",
                [.trashFolder(facts)]
            )
        }
        if facts.isExcludedFromBackup {
            return advice(
                .careful,
                "Its app keeps it out of Time Machine backups, as apps do with what they can rebuild.",
                [.reveal, .trashFolder(facts)]
            )
        }
        return advice(.review, "Oriel does not know this folder.", [.reveal, .trashFolder(facts)])
    }

    /// An app's own folder in Application Support or the containers: kept, unless the app is gone.
    private static func appData(_ facts: CleanupFacts) -> CleanupAdvice {
        if facts.apps.isEmpty, let missing = facts.missingApps.first {
            return CleanupAdvice(
                verdict: .careful, summary: "What is left of an app that is no longer installed (\(missing)): its settings and data.",
                findings: [.init(.note, "No installed app has the ID \(missing).")], methods: [.trashFolder(facts), .reveal], ruleID: nil
            )
        }
        let owner = facts.apps.first.map { "\($0.name)'s own data" } ?? "An app's own data"
        return CleanupAdvice(
            verdict: .keep, summary: "\(owner): its settings, accounts, documents or history.", findings: [], methods: [.reveal],
            ruleID: nil
        )
    }

    // MARK: Leftovers inside

    /// Older versions' folders, temporary browser profiles and caches inside, which can go even where the folder stays.
    private static func addLeftovers(_ facts: CleanupFacts, to advice: inout CleanupAdvice) {
        var found: [CleanupMethod] = []
        if !advice.methods.contains(where: { $0.id == "olderVersions" }), let older = CleanupCatalog.olderVersions(facts, of: "folders") {
            found.append(older)
        }
        if let profiles = CleanupMethod.trashItems(
            temporaryProfiles(in: facts).filter { !facts.isBusy($0.path) }, id: "temporaryProfiles",
            title: "Move the leftover temporary profiles to the Trash", detail: "The profiles in use stay."
        ) {
            found.append(profiles)
        }
        let caches = facts.cacheFolders.filter { !facts.isBusy($0.path) }
        if advice.verdict >= .careful || !advice.isKnown, !cacheNames.contains(facts.name), let method = CleanupMethod.trashItems(
            caches, id: "caches", title: "Move the caches inside to the Trash",
            detail: Set(caches.map(\.name)).sorted().joined(separator: ", ") + ". The rest stays."
        ) {
            found.append(method)
        }
        // Where the folder itself stays, the leftovers are the way to get space back.
        advice.methods = advice.verdict >= .review || advice.methods.isEmpty ? found + advice.methods : advice.methods + found
    }

    static func temporaryProfiles(in facts: CleanupFacts) -> [CleanupFacts.Child] {
        facts.children.filter { child in
            child.isFolder && temporaryProfilePatterns.contains { fnmatch($0, child.name, 0) == 0 }
        }
    }

    // MARK: What can only make it more cautious

    private static func applyRefusal(_ facts: CleanupFacts, to advice: inout CleanupAdvice) {
        guard let refusal = facts.refusal else { return }
        advice.methods.removeAll { $0.action == .trashFolder }
        if facts.refusesContents {
            advice.methods.removeAll(where: \.trashes)
            advice.raise(to: .keep)
            advice.findings.append(.init(.stop, "Oriel won't remove it or what it holds. \(refusal)"))
        } else {
            advice.findings.append(.init(.note, "Oriel keeps the folder itself. \(refusal)"))
        }
    }

    private static func applyContents(_ facts: CleanupFacts, to advice: inout CleanupAdvice) {
        if facts.isInCloud, advice.ruleID != "cloud" {
            advice.raise(to: .keep)
            advice.findings.append(.init(
                .stop,
                "It is in cloud storage: removing it removes it from the cloud and your other devices too."
            ))
        }
        if facts.repositories > 0 {
            let count = DiskFormat.count(facts.repositories, "Git repository", plural: "Git repositories")
            if advice.isKnown, advice.verdict <= .careful {
                advice.findings.append(.init(.note, "It holds \(count) its tool made, which it makes again."))
            } else {
                advice.raise(to: .keep)
                advice.findings.append(.init(.stop, "It holds \(count): work that is not pushed anywhere would be lost."))
                advice.methods.removeAll { $0.action == .trashFolder || $0.action == .trashContents }
            }
        }
        if !advice.isKnown, facts.bytes >= smallSize, facts.personalShare >= 0.5 {
            advice.raise(to: .review)
            advice.findings.append(.init(.warning, "Most of it is documents, pictures, videos, audio or archives: likely your own files."))
            if !advice.methods.contains(.showOldFiles) {
                advice.methods.insert(.showOldFiles, at: 0)
            }
        }
    }

    private static func applyUse(_ facts: CleanupFacts, ruleApps: [String], to advice: inout CleanupAdvice) {
        if !facts.users.isEmpty {
            advice.raise(to: .careful)
            let names = Set(facts.users.map(\.name)).sorted()
            advice.findings.append(.init(
                .warning,
                "In use now by \(ListFormatter.localizedString(byJoining: names)). Quit "
                    + "\(names.count == 1 ? "it" : "them") first; Oriel leaves what is in use."
            ))
            leaveBusyItems(facts, in: &advice)
        }
        let named = Set(ruleApps)
        let running = facts.apps.filter(\.isRunning) + facts.runningApps.filter { named.contains($0.bundleID) }
        var seen = Set<String>()
        let apps = running.filter { seen.insert($0.bundleID).inserted }
        guard !apps.isEmpty, advice.methods.contains(where: \.trashes) else { return }
        advice.raise(to: .careful)
        advice.appsToQuit = apps
        let names = ListFormatter.localizedString(byJoining: apps.map(\.name))
        advice.findings.append(.init(
            .warning,
            "\(names) \(apps.count == 1 ? "is" : "are") running. Quit "
                + "\(apps.count == 1 ? "it" : "them") first, so nothing is written while the files go."
        ))
    }

    /// What is in use stays: moving everything becomes moving the rest, and the folder itself stays.
    private static func leaveBusyItems(_ facts: CleanupFacts, in advice: inout CleanupAdvice) {
        let busy = facts.busyItems
        advice.methods.removeAll { $0.action == .trashFolder }
        advice.methods = advice.methods.compactMap { method in
            switch method.action {
            case .trashContents:
                CleanupMethod.trashItems(
                    facts.children.filter { !busy.contains($0.name) }, id: "trashIdle", title: "Move what it holds to the Trash, but "
                        + "what is in use", detail: "The items in use stay."
                )
            case let .trashItems(paths):
                paths.contains(where: facts.isBusy) ? idle(method, paths: paths, facts: facts) : method
            default:
                method
            }
        }
    }

    /// A method's items without those in use; nil when every one is.
    private static func idle(_ method: CleanupMethod, paths: [String], facts: CleanupFacts) -> CleanupMethod? {
        let idle = paths.filter { !facts.isBusy($0) }
        guard !idle.isEmpty else { return nil }
        let sizes = Dictionary(facts.children.map { ($0.path, $0.bytes) }, uniquingKeysWith: { first, _ in first })
        let bytes = idle.allSatisfy { sizes[$0] != nil } ? idle.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) } : nil
        return CleanupMethod(id: method.id, title: method.title, detail: method.detail, action: .trashItems(idle), bytes: bytes)
    }

    private static func applyOwnership(_ facts: CleanupFacts, to advice: inout CleanupAdvice) {
        guard !facts.isRemovable, advice.methods.contains(where: \.trashes) else { return }
        advice.methods.removeAll(where: \.trashes)
        advice.findings.append(.init(
            .warning,
            "Only its owner, macOS's root account or another user, may remove it, so Oriel can't "
                + "move it to the Trash."
        ))
        if advice.methods.isEmpty {
            let detail = "Drag it to the Trash there; Finder asks for an administrator's password."
            advice.methods = [CleanupMethod(id: "reveal", title: "Show it in Finder", detail: detail, action: .reveal)]
        }
    }

    private static func addNotes(_ facts: CleanupFacts, to advice: inout CleanupAdvice) {
        if facts.isTaggedCache {
            advice.findings.append(.init(.good, "The tool that made it tagged it as a cache (CACHEDIR.TAG)."))
        }
        if facts.isExcludedFromBackup, advice.verdict <= .careful {
            advice.findings.append(.init(.good, "Its app keeps it out of Time Machine backups, as apps do with what they can rebuild."))
        }
        if let lastUsed = facts.lastUsed, facts.now.timeIntervalSince(lastUsed) < 3600 {
            advice.findings.append(.init(.note, "Something changed in it in the last hour."))
        }
        if facts.bytes < smallSize {
            advice.findings.append(.init(.note, "It takes \(DiskFormat.bytes(facts.bytes)), so cleaning it up frees little."))
        }
    }
}
