// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Hotkeys",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Hotkeys", targets: ["Hotkeys"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "Hotkeys",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")]
        ),
        .testTarget(
            name: "HotkeysTests",
            dependencies: ["Hotkeys", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
