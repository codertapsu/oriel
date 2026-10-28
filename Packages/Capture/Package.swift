// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Capture",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Capture", targets: ["Capture"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../Permissions"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "Capture",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "Permissions", package: "Permissions"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "CaptureTests",
            dependencies: ["Capture", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
