// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Editor",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Editor", targets: ["Editor"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "Editor",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "EditorTests",
            dependencies: ["Editor", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
