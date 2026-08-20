// swift-tools-version: 5.9

import PackageDescription

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
