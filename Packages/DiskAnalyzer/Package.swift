// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiskAnalyzer",
    platforms: [.macOS("26.0")],
    products: [.library(name: "DiskAnalyzer", targets: ["DiskAnalyzer"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "DiskAnalyzer",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "DiskAnalyzerTests",
            dependencies: [
                "DiskAnalyzer",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
