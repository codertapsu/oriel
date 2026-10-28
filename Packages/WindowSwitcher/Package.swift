// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WindowSwitcher",
    platforms: [.macOS("26.0")],
    products: [.library(name: "WindowSwitcher", targets: ["WindowSwitcher"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../PrivateAPIs"),
        .package(path: "../Permissions"),
        .package(path: "../Hotkeys"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "WindowSwitcher",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "PrivateAPIs", package: "PrivateAPIs"),
                .product(name: "Permissions", package: "Permissions"),
                .product(name: "Hotkeys", package: "Hotkeys"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "WindowSwitcherTests",
            dependencies: [
                "WindowSwitcher",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
                .product(name: "PrivateAPIs", package: "PrivateAPIs"),
                .product(name: "Hotkeys", package: "Hotkeys"),
                .product(name: "SharedUI", package: "SharedUI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
