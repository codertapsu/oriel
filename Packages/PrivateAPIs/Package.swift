// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PrivateAPIs",
    platforms: [.macOS("26.0")],
    products: [.library(name: "PrivateAPIs", targets: ["PrivateAPIs"])],
    targets: [
        .target(name: "PrivateAPIs"),
        .testTarget(name: "PrivateAPIsTests", dependencies: ["PrivateAPIs"]),
    ],
    swiftLanguageModes: [.v6]
)
