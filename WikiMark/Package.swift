// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WikiMark",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/commonmark/cmark.git", from: "0.31.1")
    ],
    targets: [
        .executableTarget(
            name: "WikiMark",
            dependencies: [
                .product(name: "cmark", package: "cmark")
            ],
            path: "WikiMark"
        )
    ]
)
