// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unlink",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Unlink",
            targets: ["Unlink"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Unlink",
            dependencies: [],
            path: "Sources/Unlink",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
