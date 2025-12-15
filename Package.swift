// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "HighlightKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "HighlightKit",
            targets: ["HighlightKit"]
        ),
    ],
    targets: [
        .target(
            name: "HighlightKit",
            path: "Sources/HighlightKit"
        )
    ]
)
