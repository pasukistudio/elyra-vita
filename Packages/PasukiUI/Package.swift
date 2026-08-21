// swift-tools-version: 5.9

import PackageDescription

// MARK: - PasukiUI-Paketdefinition

/// Plattformen, Produkt und Testziel des gemeinsamen SwiftUI-Bausteinpakets.
let package = Package(
    name: "PasukiUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PasukiUI",
            targets: ["PasukiUI"]
        )
    ],
    targets: [
        .target(
            name: "PasukiUI"
        ),
        .testTarget(
            name: "PasukiUITests",
            dependencies: ["PasukiUI"]
        )
    ]
)
