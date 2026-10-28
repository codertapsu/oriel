// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Permissions",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Permissions", targets: ["Permissions"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "Permissions",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")]
        ),
        .testTarget(name: "PermissionsTests", dependencies: ["Permissions"]),
    ],
    swiftLanguageModes: [.v6]
)
