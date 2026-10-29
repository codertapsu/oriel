// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ActivityMonitor",
    platforms: [.macOS("26.0")],
    products: [.library(name: "ActivityMonitor", targets: ["ActivityMonitor"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "ActivityMonitor",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ActivityMonitorTests",
            dependencies: [
                "ActivityMonitor",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
