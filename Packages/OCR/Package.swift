// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OCR",
    platforms: [.macOS("26.0")],
    products: [.library(name: "OCR", targets: ["OCR"])],
    dependencies: [
        .package(path: "../OrielCore"),
    ],
    targets: [
        .target(
            name: "OCR",
            dependencies: [.product(name: "OrielCore", package: "OrielCore")]
        ),
        .testTarget(
            name: "OCRTests",
            dependencies: ["OCR", .product(name: "OrielTestSupport", package: "OrielCore")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
