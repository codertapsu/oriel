// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "IPC",
    platforms: [.macOS("26.0")],
    products: [.library(name: "IPC", targets: ["IPC"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "IPC",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")]
        ),
        .testTarget(name: "IPCTests", dependencies: ["IPC"]),
    ],
    swiftLanguageModes: [.v6]
)
