// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Present",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Present",
            path: "Sources/Present"
        )
    ]
)
