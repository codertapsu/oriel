// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [.macOS("26.0")],
    products: [.library(name: "SharedUI", targets: ["SharedUI"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "SharedUI",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "SharedUITests", dependencies: ["SharedUI"]),
    ],
    swiftLanguageModes: [.v6]
)
