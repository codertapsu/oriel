@testable import DiskAnalyzer
import Foundation
import Testing

/// Clean Up's judgment (PLAN §7.10 item 19), from made-up facts: the folders the catalog knows, those it judges by their
/// place, name and contents, and what makes either more cautious. The first three are the examples it was built for.
struct CleanupAdvisorTests {
    private static let home = "/Users/me"
    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let day: TimeInterval = 86400

    private static func facts(_ path: String, children: [CleanupFacts.Child] = [], bytes: Int64 = 5_000_000_000) -> CleanupFacts {
        var facts = CleanupFacts(path: path, home: home, bytes: bytes, fileCount: 1000, folderCount: 100, children: children)
        facts.names = Set(children.map(\.name))
        facts.now = now
        return facts
    }

    private static func child(_ name: String, in folder: String, bytes: Int64 = 500_000_000, daysAgo: Double = 1) -> CleanupFacts.Child {
        CleanupFacts.Child(
            name: name,
            path: folder + "/" + name,
            bytes: bytes,
            isFolder: true,
            lastUsed: now.addingTimeInterval(-daysAgo * day)
        )
    }

    private static func paths(of method: CleanupMethod?) -> [String] {
        guard case let .trashItems(paths)? = method?.action else { return [] }
        return paths.map { ($0 as NSString).lastPathComponent }.sorted()
    }

    // MARK: The examples

    private static let gradle = home + "/.gradle/caches"
    private static let gradleChildren = ["9.1.0", "9.3.1", "9.4.1", "9.6.1", "9.8.1", "build-cache-1", "jars-9", "journal-1", "modules-2"]
        .map { child($0, in: gradle) }

    @Test func gradlesCachesGoVersionByVersion() {
        var facts = Self.facts(Self.gradle, children: Self.gradleChildren)
        facts.isTaggedCache = true
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.ruleID == "gradleCaches" && advice.verdict == .safe)
        #expect(advice.methods.first?.id == "olderVersions")
        #expect(Self.paths(of: advice.methods.first) == ["9.1.0", "9.3.1", "9.4.1", "9.6.1"])
        #expect(advice.methods.first?.bytes == 2_000_000_000)
        #expect(advice.methods.contains { $0.action == .trashContents })
        #expect(advice.findings.contains { $0.kind == .good && $0.text.contains("CACHEDIR.TAG") })
    }

    @Test func aRunningGradleMakesItCarefulAndKeepsWhatItUses() {
        var facts = Self.facts(Self.gradle, children: Self.gradleChildren)
        facts.users = [CleanupFacts.User(pid: 42, name: "java", items: ["modules-2"], paths: [Self.gradle + "/modules-2/files-2.1/x.jar"])]
        facts.runningApps = [CleanupFacts.App(bundleID: "com.google.android.studio", name: "Android Studio", isRunning: true)]
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .careful)
        #expect(advice.appsToQuit.map(\.name) == ["Android Studio"])
        #expect(advice.findings.contains { $0.kind == .warning && $0.text.contains("java") })
        // Moving everything becomes moving all but what is in use.
        let idle = advice.methods.first { $0.id == "trashIdle" }
        #expect(idle != nil && !Self.paths(of: idle).contains("modules-2") && Self.paths(of: idle).contains("9.8.1"))
        #expect(!advice.methods.contains { $0.action == .trashContents || $0.action == .trashFolder })
    }

    @Test func headlessChromesLeftoverProfilesGo() {
        let folder = Self.home + "/Library/Application Support/Google/Chrome-headless"
        let children = ["scoped_dir07Ygn4", "scoped_dir0aazft", "scoped_dir0AEZOV"].map { Self.child($0, in: folder) }
        var facts = Self.facts(folder, children: children, bytes: 1_500_000_000)
        var advice = CleanupAdvisor.advise(facts)
        #expect(advice.ruleID == nil && advice.verdict == .safe)
        #expect(advice.summary.contains("Temporary browser profiles"))
        #expect(advice.methods.first?.id == "temporaryProfiles" && Self.paths(of: advice.methods.first).count == 3)
        // The one a test is running in stays.
        let user = CleanupFacts.User(
            pid: 7, name: "Google Chrome for Testing", items: ["scoped_dir0aazft"], paths: [folder + "/scoped_dir0aazft/Default"]
        )
        facts.users = [user]
        advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .careful)
        #expect(Self.paths(of: advice.methods.first) == ["scoped_dir07Ygn4", "scoped_dir0AEZOV"])
    }

    @Test func coreSimulatorsCachesGoThroughItsOwnCommand() {
        var facts = Self.facts(
            "/Library/Developer/CoreSimulator/Caches",
            children: [Self.child("dyld", in: "/Library/Developer/CoreSimulator/Caches")]
        )
        facts.isRemovable = false
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.ruleID == "systemSimulatorCaches" && advice.verdict == .safe)
        #expect(advice.methods.map(\.action) == [.run(.removeSimulatorCaches)])
        #expect(CleanupCommand.removeSimulatorCaches.commandLine == "xcrun simctl runtime dyld_shared_cache remove --all")
        #expect(!advice.findings.contains { $0.kind == .warning })
    }

    // MARK: The catalog

    @Test func pathsMatchNameByName() {
        #expect(CleanupRule.path("~/Library/Caches/com.spotify.client", matches: "~/Library/Caches/*"))
        #expect(!CleanupRule.path("~/Library/Caches", matches: "~/Library/Caches/*"))
        #expect(!CleanupRule.path("/Library/Caches/x", matches: "~/Library/Caches/*"))
        #expect(CleanupRule.path("~/Library/Developer/Xcode/iOS DeviceSupport", matches: "~/Library/Developer/Xcode/* DeviceSupport"))
        #expect(CleanupRule.path("~/Pictures/Photos Library.photoslibrary", matches: "~/Pictures/*.photoslibrary"))
    }

    @Test func aParticularRuleSpeaksBeforeAGeneralOne() {
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Caches/JetBrains")).ruleID == "jetBrainsCaches")
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Logs/JetBrains")).ruleID == "jetBrainsCaches")
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Caches/com.spotify.client")).ruleID == "appCache")
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/.cache/huggingface")).ruleID == "huggingFace")
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/.cache/pip")).ruleID == "toolCaches")
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Developer/Xcode/Archives")).verdict == .keep)
    }

    @Test func aProjectsBuildFolderIsKnownByTheFileNextToIt() {
        var modules = Self.facts(Self.home + "/code/site/node_modules")
        modules.siblingNames = ["package.json", "src"]
        let advice = CleanupAdvisor.advise(modules)
        #expect(advice.ruleID == "nodeModules" && advice.verdict == .safe && advice.methods.first?.action == .trashFolder)
        modules.siblingNames = ["src"]
        #expect(CleanupAdvisor.advise(modules).ruleID == nil)
        var environment = Self.facts(Self.home + "/code/tool/env")
        environment.names = ["pyvenv.cfg", "lib", "bin"]
        #expect(CleanupAdvisor.advise(environment).ruleID == "pythonEnvironment")
    }

    // MARK: Folders Oriel judges

    @Test func appDataStaysButLeftoversInsideGo() {
        let folder = Self.home + "/Library/Application Support/Google"
        var facts = Self.facts(
            folder,
            children: ["AndroidStudio2025.1.2", "AndroidStudio2025.3.1", "AndroidStudio2025.3.2"].map { Self.child($0, in: folder) }
        )
        facts.cacheFolders = [Self.child("GPUCache", in: folder + "/AndroidStudio2025.3.2")]
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .keep)
        #expect(Self.paths(of: advice.methods.first) == ["AndroidStudio2025.1.2", "AndroidStudio2025.3.1"])
        #expect(advice.methods.contains { $0.id == "caches" })
        #expect(advice.methods.last?.action == .reveal)
    }

    @Test func whatIsLeftOfARemovedAppCanGo() {
        var facts = Self.facts(Self.home + "/Library/Application Support/com.gone.app")
        facts.missingApps = ["com.gone.app"]
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .careful && advice.methods.first?.action == .trashFolder)
        #expect(advice.summary.contains("com.gone.app"))
        facts.missingApps = []
        facts.apps = [CleanupFacts.App(bundleID: "com.example.notes", name: "Notes Plus", isRunning: false)]
        let kept = CleanupAdvisor.advise(facts)
        #expect(kept.verdict == .keep && kept.summary.hasPrefix("Notes Plus's own data"))
    }

    @Test func aBrowsersProfilesStayAndItsCachesGo() {
        let folder = Self.home + "/Library/Application Support/BraveSoftware/Brave-Browser"
        var facts = Self.facts(folder, children: [Self.child("Default", in: folder)])
        facts.names = ["Local State", "Default"]
        facts.cacheFolders = [Self.child("Cache", in: folder + "/Default"), Self.child("Code Cache", in: folder + "/Default")]
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .keep && advice.summary.contains("Chromium"))
        #expect(advice.methods.first?.id == "caches" && advice.methods.first?.bytes == 1_000_000_000)
    }

    @Test func aTaggedOrCacheNamedFolderIsACache() {
        var tagged = Self.facts(Self.home + "/work/.something")
        tagged.isTaggedCache = true
        #expect(CleanupAdvisor.advise(tagged).verdict == .safe)
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Application Support/Slack/Code Cache")).verdict == .safe)
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Library/Application Support/Slack/Cache/Cache_Data")).verdict == .safe)
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/stuff")).verdict == .review)
    }

    @Test func yourOwnFilesAreReviewedInOldFiles() {
        var facts = Self.facts(Self.home + "/Archive 2019")
        facts.categories = [.image: 3_000_000_000, .video: 1_000_000_000, .other: 1_000_000_000]
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.verdict == .review && advice.methods.first == .showOldFiles)
        #expect(CleanupAdvisor.advise(Self.facts(Self.home + "/Downloads/old")).methods.first == .showOldFiles)
    }

    // MARK: What makes it more cautious

    @Test func aRefusedFolderKeepsItselfOrEverything() {
        var library = Self.facts(Self.home + "/Library/Caches")
        library.refusal = SafetyRules.Refusal.libraryFolder.message
        var advice = CleanupAdvisor.advise(library)
        #expect(advice.verdict == .safe && advice.methods.contains { $0.action == .trashContents })
        #expect(!advice.methods.contains { $0.action == .trashFolder })
        var system = Self.facts("/System/Library/Caches")
        system.refusal = SafetyRules.Refusal.system.message
        system.refusesContents = true
        advice = CleanupAdvisor.advise(system)
        #expect(advice.verdict == .keep && !advice.methods.contains { $0.trashes })
        #expect(advice.findings.contains { $0.kind == .stop })
    }

    @Test func repositoriesAndTheCloudAreKept() {
        var code = Self.facts(Self.home + "/old projects")
        code.repositories = 3
        let advice = CleanupAdvisor.advise(code)
        #expect(advice.verdict == .keep && !advice.methods.contains { $0.action == .trashFolder })
        var crates = Self.facts(Self.home + "/.cargo/git")
        crates.repositories = 12
        #expect(CleanupAdvisor.advise(crates).verdict == .safe)
        var cloud = Self.facts(Self.home + "/Library/CloudStorage/GoogleDrive-me/Photos")
        cloud.isInCloud = true
        #expect(CleanupAdvisor.advise(cloud).verdict == .keep)
    }

    @Test func whatOnlyAnAdministratorMayRemoveIsShownInFinder() {
        var facts = Self.facts("/opt/tools/cache-data")
        facts.isRemovable = false
        let advice = CleanupAdvisor.advise(facts)
        #expect(!advice.methods.isEmpty && advice.methods.allSatisfy { $0.action == .reveal })
        #expect(advice.findings.contains { $0.text.contains("Only its owner") })
    }

    @Test func aSmallOrBusyFolderSaysSo() {
        var facts = Self.facts(Self.home + "/Library/Caches/com.example.tiny", bytes: 2_000_000)
        facts.lastUsed = Self.now.addingTimeInterval(-60)
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.findings.contains { $0.text.contains("frees little") })
        #expect(advice.findings.contains { $0.text.contains("last hour") })
    }

    @Test func unusedItemsAreTheOnesNotUsedForTheWholePeriod() {
        let folder = Self.home + "/Library/Developer/Xcode/iOS DeviceSupport"
        let facts = Self.facts(
            folder,
            children: [Self.child("iPhone15,2 17.0", in: folder, daysAgo: 400), Self.child("iPhone15,2 18.4", in: folder, daysAgo: 5)]
        )
        let advice = CleanupAdvisor.advise(facts)
        #expect(advice.ruleID == "deviceSupport")
        #expect(Self.paths(of: advice.methods.first) == ["iPhone15,2 17.0"])
    }

    // MARK: Versions

    @Test func versionsAreReadFromNames() {
        #expect(VersionedNames.parse("9.1.0")?.version == [9, 1, 0])
        #expect(VersionedNames.parse("AndroidStudio2025.3.2")?.stem == "AndroidStudio#")
        #expect(VersionedNames.parse("gradle-8.5-bin")?.version == [8, 5])
        #expect(VersionedNames.parse("scoped_dir07Ygn4") == nil)
        let items = ["9.10.0", "9.9.1", "gradle-8.5-bin", "other"].map { Self.child($0, in: "/x") }
        #expect(VersionedNames.older(among: items).map(\.name) == ["9.9.1"])
        #expect(VersionedNames.newest(among: items).map(\.name) == ["9.10.0"])
    }

    @Test func appleIntelligenceReadsNamesNotTheHomeFolder() {
        let folder = Self.home + "/Library/Application Support/Mystery"
        var facts = Self.facts(folder, children: [Self.child("blobs", in: folder)])
        facts.isExcludedFromBackup = true
        let prompt = CleanupExplainer.prompt(for: facts)
        #expect(prompt.contains("Folder: ~/Library/Application Support/Mystery"))
        #expect(prompt.contains("- blobs (folder"))
        #expect(prompt.contains("Time Machine"))
        #expect(!prompt.contains(Self.home))
    }
}
