// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WindowTiling",
    platforms: [.macOS("26.0")],
    products: [.library(name: "WindowTiling", targets: ["WindowTiling"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
        .package(path: "../Permissions"),
    ],
    targets: [
        .target(
            name: "WindowTiling",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
                .product(name: "Permissions", package: "Permissions"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WindowTilingTests",
            dependencies: [
                "WindowTiling",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
