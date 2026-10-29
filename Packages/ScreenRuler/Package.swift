// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenRuler",
    platforms: [.macOS("26.0")],
    products: [.library(name: "ScreenRuler", targets: ["ScreenRuler"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
        .package(path: "../Permissions"),
    ],
    targets: [
        .target(
            name: "ScreenRuler",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
                .product(name: "Permissions", package: "Permissions"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ScreenRulerTests",
            dependencies: [
                "ScreenRuler",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
