/// Developer tools' folders: their caches and downloads, which they fetch or build again.
nonisolated extension CleanupCatalog {
    static let gradleApps = ["com.google.android.studio", "com.jetbrains.intellij", "com.jetbrains.intellij.ce"]

    static let developerTools: [CleanupRule] = [
        CleanupRule(
            id: "gradleCaches",
            matches: [.path("~/.gradle/caches")],
            verdict: .safe,
            summary: "Gradle's caches: the dependencies it downloaded and its build caches, with a folder for each Gradle version "
                + "that ran.",
            afterwards: "Gradle downloads and builds again what a build needs, so the next build takes longer.",
            apps: gradleApps,
            methods: { facts in
                [
                    olderVersions(facts, of: "caches"),
                    .trashContents(facts, detail: "Every version's. Stop Gradle first: `./gradlew --stop`."),
                ]
                .compactMap(\.self)
            }
        ),
        CleanupRule(
            id: "gradleDistributions",
            matches: [.path("~/.gradle/wrapper/dists"), .path("~/.gradle/daemon"), .path("~/.gradle/native")],
            verdict: .safe,
            summary: "Gradle versions the Gradle wrapper downloaded for your projects, or the logs of Gradle's daemons, a folder "
                + "per version.",
            afterwards: "A project that asks for a version gets it downloaded again.",
            apps: gradleApps,
            methods: { facts in [olderVersions(facts, of: "downloads"), .trashContents(facts)].compactMap(\.self) }
        ),
        CleanupRule(
            id: "gradleHome",
            matches: [.path("~/.gradle")],
            verdict: .careful,
            summary: "Gradle's home: its caches, the Gradle versions and JDKs it downloaded, and your settings (gradle.properties "
                + "and init scripts), which must stay.",
            apps: gradleApps,
            methods: { facts in
                let rebuilt: Set = ["caches", "wrapper", "daemon", ".tmp", "native", "jdks", "kotlin-profile", "workers"]
                let busy = facts.busyItems
                return [
                    .trashItems(
                        facts.children.filter { rebuilt.contains($0.name) && !busy.contains($0.name) }, id: "gradleRebuilt",
                        title: "Move the caches, downloads and logs to the Trash",
                        detail: "Your settings, gradle.properties and init.d, stay. Stop Gradle first: `./gradlew --stop`."
                    ),
                ].compactMap(\.self)
            }
        ),
        CleanupRule(
            id: "maven",
            matches: [.path("~/.m2/repository")],
            verdict: .safe,
            summary: "Maven's local repository: the dependencies it downloaded.",
            afterwards: "Maven downloads what a build needs again.",
            methods: contents
        ),
        CleanupRule(
            id: "npm",
            matches: [.path("~/.npm"), .path("~/.npm/_cacache"), .path("~/.npm/_npx")],
            verdict: .safe,
            summary: "npm's cache: packages it downloaded before.",
            afterwards: "npm downloads them again when a project needs them.",
            methods: contents
        ),
        CleanupRule(
            id: "pnpm",
            matches: [.path("~/Library/pnpm/store")],
            verdict: .careful,
            summary: "pnpm's store: your projects link their packages from here.",
            methods: { _ in
                [
                    .copy(
                        "pnpm store prune",
                        title: "Copy pnpm's command",
                        detail: "It removes the packages no project uses. Run it in Terminal."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "cargo",
            matches: [.path("~/.cargo/registry"), .path("~/.cargo/git")],
            verdict: .safe,
            summary: "Crates Cargo downloaded, and the Git checkouts of crates from Git.",
            afterwards: "Cargo downloads what a build needs again.",
            methods: contents
        ),
        CleanupRule(
            id: "goModules",
            matches: [.path("~/go/pkg/mod")],
            verdict: .safe,
            summary: "Go's module cache: the modules it downloaded.",
            afterwards: "Go downloads what a build needs again.",
            methods: { _ in
                [
                    .copy(
                        "go clean -modcache", title: "Copy Go's command that clears it",
                        detail: "Go keeps these files read-only, so its own command is the way to remove them. Run it in Terminal."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "cocoapods",
            matches: [.path("~/.cocoapods/repos")],
            verdict: .safe,
            summary: "Copies of CocoaPods' spec repositories.",
            afterwards: "CocoaPods fetches them again when needed.",
            methods: contents
        ),
        CleanupRule(
            id: "huggingFace",
            matches: [.path("~/.cache/huggingface")],
            verdict: .careful,
            summary: "Models and data sets Hugging Face tools downloaded, often many gigabytes.",
            afterwards: "A tool downloads a model again when it needs it, which can take long.",
            methods: { facts in [unused(facts, days: 90, noun: "models"), .trashContents(facts)].compactMap(\.self) }
        ),
        CleanupRule(
            id: "toolCaches",
            matches: [.path("~/.cache"), .path("~/.cache/*")],
            verdict: .safe,
            summary: "Caches of command-line tools.",
            afterwards: "The tools make them again when they need them.",
            methods: contents
        ),
        CleanupRule(
            id: "ollama",
            matches: [.path("~/.ollama/models")],
            verdict: .careful,
            summary: "Models Ollama downloaded.",
            afterwards: "Ollama downloads a model again when you pull it.",
            methods: { _ in
                [
                    .copy(
                        "ollama list",
                        title: "Copy Ollama's list command",
                        detail: "Then remove the models you do not use with `ollama rm`."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "androidEmulators",
            matches: [.path("~/.android/avd")],
            verdict: .careful,
            summary: "Android emulators, with the apps and data on them.",
            methods: { _ in
                [.openApp("com.google.android.studio", name: "Android Studio", detail: "Device Manager deletes the ones you do not use.")]
            }
        ),
        CleanupRule(
            id: "androidSDK",
            matches: [.path("~/Library/Android/sdk"), .path("~/Library/Android/sdk/*")],
            verdict: .careful,
            summary: "The Android SDK: platforms, build tools and emulator images.",
            methods: { _ in
                [
                    .openApp(
                        "com.google.android.studio", name: "Android Studio",
                        detail: "Settings → Languages & Frameworks → Android SDK removes the parts you no longer use."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "docker",
            matches: [.path("~/Library/Containers/com.docker.docker")],
            verdict: .keep,
            summary: "Docker Desktop's disk: your images, containers and volumes.",
            methods: { _ in
                [
                    .openApp(
                        "com.docker.docker",
                        name: "Docker Desktop",
                        detail: "Troubleshoot → Clean / Purge data, or remove images there."
                    ),
                    .copy(
                        "docker system prune",
                        title: "Copy Docker's command",
                        detail: "It removes stopped containers and unused images."
                    ),
                ]
            }
        ),
        CleanupRule(
            id: "homebrew",
            matches: [.path("/opt/homebrew/Cellar"), .path("/usr/local/Cellar")],
            verdict: .careful,
            summary: "The packages Homebrew installed, with the older versions it keeps.",
            methods: { _ in
                [.copy("brew cleanup --prune=all", title: "Copy Homebrew's command", detail: "It removes older versions and downloads.")]
            }
        ),
        CleanupRule(
            id: "jetBrainsCaches",
            matches: [.path("~/Library/Caches/JetBrains"), .path("~/Library/Logs/JetBrains"), .path("~/Library/Caches/Google")],
            verdict: .safe,
            summary: "Caches, indexes and logs of JetBrains IDEs and Android Studio, a folder per version.",
            afterwards: "The IDE indexes your projects again.",
            methods: { facts in [olderVersions(facts, of: "caches"), .trashContents(facts)].compactMap(\.self) }
        ),
    ]
}
