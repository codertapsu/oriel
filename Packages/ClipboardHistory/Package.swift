// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClipboardHistory",
    platforms: [.macOS("26.0")],
    products: [.library(name: "ClipboardHistory", targets: ["ClipboardHistory"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "ClipboardHistory",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ClipboardHistoryTests",
            dependencies: [
                "ClipboardHistory",
                .product(name: "OrielTestSupport", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
