// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Upload",
    platforms: [.macOS("26.0")],
    products: [.library(name: "Upload", targets: ["Upload"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "Upload",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ]
        ),
        .testTarget(
            name: "UploadTests",
            dependencies: ["Upload", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
