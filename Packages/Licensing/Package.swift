// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Licensing",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Licensing", targets: ["Licensing"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "Licensing",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "LicensingTests",
            dependencies: ["Licensing", .product(name: "OrielCore", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
