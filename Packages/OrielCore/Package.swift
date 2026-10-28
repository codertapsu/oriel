// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OrielCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "OrielCore", targets: ["OrielCore"]),
        .library(name: "OrielTestSupport", targets: ["OrielTestSupport"]), // for test targets only
    ],
    targets: [
        .target(name: "OrielCore"),
        .target(name: "OrielTestSupport"),
        .testTarget(name: "OrielCoreTests", dependencies: ["OrielCore", "OrielTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
