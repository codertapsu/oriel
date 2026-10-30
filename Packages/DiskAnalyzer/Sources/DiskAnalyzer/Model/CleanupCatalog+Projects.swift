/// Folders inside projects that their build tools make, recognized by name and by the project's file next to them.
nonisolated extension CleanupCatalog {
    static let gradleProjectFiles: Set = ["settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts"]
    static let javaScriptProjectFiles: Set = ["package.json"]

    static let projects: [CleanupRule] = [
        CleanupRule(
            id: "nodeModules",
            matches: [.name("node_modules", besides: javaScriptProjectFiles)],
            verdict: .safe,
            summary: "A project's JavaScript packages.",
            afterwards: "`npm install` (or yarn or pnpm) brings them back.",
            methods: folder
        ),
        CleanupRule(
            id: "javaScriptBuild",
            matches: [".next", ".nuxt", ".turbo", ".parcel-cache", ".svelte-kit", ".angular"].map { .name(
                $0,
                besides: javaScriptProjectFiles
            ) },
            verdict: .safe,
            summary: "A JavaScript project's build cache.",
            afterwards: "The next build makes it again.",
            methods: folder
        ),
        CleanupRule(
            id: "swiftBuild",
            matches: [.name(".build", besides: ["Package.swift"])],
            verdict: .safe,
            summary: "A Swift package's build folder.",
            afterwards: "The next build makes it again.",
            methods: folder
        ),
        CleanupRule(
            id: "gradleProject",
            matches: [.name(".gradle", besides: gradleProjectFiles), .name("build", besides: gradleProjectFiles)],
            verdict: .safe,
            summary: "A Gradle project's caches or build outputs.",
            afterwards: "The next build makes them again.",
            methods: folder
        ),
        CleanupRule(
            id: "cargoTarget",
            matches: [.name("target", besides: ["Cargo.toml", "pom.xml"])],
            verdict: .safe,
            summary: "A Rust or Maven project's build outputs.",
            afterwards: "The next build makes them again.",
            methods: folder
        ),
        CleanupRule(
            id: "pods",
            matches: [.name("Pods", besides: ["Podfile"])],
            verdict: .safe,
            summary: "A project's CocoaPods.",
            afterwards: "`pod install` brings them back.",
            methods: folder
        ),
        CleanupRule(
            id: "dartTool",
            matches: [.name(".dart_tool", besides: ["pubspec.yaml"])],
            verdict: .safe,
            summary: "A Dart or Flutter project's build cache.",
            afterwards: "`flutter pub get` brings it back.",
            methods: folder
        ),
        CleanupRule(
            id: "pythonCaches",
            matches: ["__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox"].map { .name($0, besides: []) },
            verdict: .safe,
            summary: "Python's compiled files, or a Python tool's cache.",
            afterwards: "Python and the tool make them again.",
            methods: folder
        ),
        CleanupRule(
            id: "pythonEnvironment",
            matches: [.holding(["pyvenv.cfg"])],
            verdict: .careful,
            summary: "A Python virtual environment: the packages installed for one project.",
            afterwards: "Make it again from the project's requirements, with `python -m venv` and `pip install`.",
            methods: folder
        ),
    ]
}
