// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OrielTranslation",
    platforms: [.macOS("26.0")],
    products: [.library(name: "OrielTranslation", targets: ["OrielTranslation"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../OCR"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "OrielTranslation",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OCR", package: "OCR"),
                .product(name: "SharedUI", package: "SharedUI"),
            ]
        ),
        .testTarget(
            name: "OrielTranslationTests",
            dependencies: ["OrielTranslation", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
