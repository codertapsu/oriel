// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Recording",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Recording", targets: ["Recording"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../Permissions"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "Recording",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "Permissions", package: "Permissions"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "RecordingTests",
            dependencies: ["Recording", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
