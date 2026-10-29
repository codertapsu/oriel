// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ColorPicker",
    platforms: [.macOS("26.0")],
    products: [.library(name: "ColorPicker", targets: ["ColorPicker"])],
    dependencies: [
        .package(path: "../OrielCore"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "ColorPicker",
            dependencies: [
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "SharedUI", package: "SharedUI"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ColorPickerTests",
            dependencies: [
                "ColorPicker",
                .product(name: "OrielCore", package: "OrielCore"),
                .product(name: "OrielTestSupport", package: "OrielCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
